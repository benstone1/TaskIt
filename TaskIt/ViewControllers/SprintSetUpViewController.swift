import RealmSwift
import RxSwift

class SprintSetUpViewController: UIViewController {

    static func fromStoryboard(with project: Project) -> SprintSetUpViewController {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SprintSetUpViewController") as! SprintSetUpViewController
        vc.viewModel = ViewModel(project: project)

        return vc
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var taskItButton: UIButton!
    @IBOutlet weak var picker: UIPickerView!

    lazy var editButton: UIBarButtonItem = {
        let edit = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editButtonTapped))
        return edit
    }()

    lazy var doneButton: UIBarButtonItem = {
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        return done
    }()

    var viewModel: ViewModel!

    private let disposeBag = DisposeBag()
    private var batchUpdates = [TableViewUpdates]()

    override func viewDidLoad() {
        super.viewDidLoad()
        bindUiToViewModel()
        viewModel.view(.didLoad)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.view(.willAppear)
        tableView.isEditing = false
        navigationItem.rightBarButtonItem = editButton
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.view(.didAppear)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.view(.willDisappear)
        navigationItem.rightBarButtonItem = nil
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.view(.didDisappear)
    }

    @objc private func editButtonTapped() {
        navigationItem.rightBarButtonItem = nil
        navigationItem.rightBarButtonItem = doneButton

        tableView.isEditing = true
    }

    @objc private func doneButtonTapped() {
        navigationItem.rightBarButtonItem = nil
        navigationItem.rightBarButtonItem = editButton

        tableView.isEditing = false
    }

    private func bindUiToViewModel() {
        viewModel.tableViewUpdates
            .observeOn(MainScheduler.instance)
            .subscribeNext { [weak self] updates in
                let reloads = updates.flatMap { update in
                    return update.reloads.map {
                        IndexPath(row: $0, section: update.section)
                    }
                }
                let deletions = updates.flatMap { update in
                    return update.deletions.map {
                        IndexPath(row: $0, section: update.section)
                    }
                }
                let insertions = updates.flatMap { update in
                    return update.inserts.map {
                        IndexPath(row: $0, section: update.section)
                    }
                }

                self?.tableView.performBatchUpdates({
                    self?.tableView.deleteRows(at: deletions, with: .fade)
                    self?.tableView.insertRows(at: insertions, with: .automatic)
                    self?.tableView.reloadRows(at: reloads, with: .automatic)
                }, completion: nil)
        }.disposed(by: disposeBag)

        viewModel.taskItButtonEnabled
            .observeOn(MainScheduler.instance)
            .subscribeNext { [weak self] isEnabled in
                self?.taskItButton.isEnabled = isEnabled
                self?.taskItButton.backgroundColor = isEnabled ? .ocean : .fog
        }.disposed(by: disposeBag)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else { return }
        switch identifier {
        case "TaskUpdatingSegue":
            let vc = segue.destination as! TaskUpdateViewController
            guard let indexPath = tableView.indexPathForSelectedRow,
                let task = viewModel.task(for: indexPath)
                else { fatalError() }
            viewModel.watchForUpdates(taskPath: indexPath)
            vc.mode = .update(task)
        case "CreateTaskSegue":
            let vc = segue.destination as! TaskUpdateViewController
            vc.mode = .create
            vc.onComplete = { [weak self] task in
                self?.viewModel.insert(newTask: task)
            }
        default: break
        }
    }

    @IBAction func taskItTapped(_ sender: UIButton) {
        guard let maxTime = viewModel.hoursSelectedInMinutes else { return }
        let vc = SprintConfirmationViewController.fromStoryboard(with: viewModel.project, maxTime: maxTime)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension SprintSetUpViewController: UIPickerViewDelegate,
UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 101
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if row == 0 {
            return "No Selection"
        }

        if row % 2 == 0 {
            return String(format: "%.0f", Float(row) / 2.0)
        } else {
            return String(format: "%.1f", Float(row) / 2.0)
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        viewModel.didSelectHours(row: row)
    }
}

extension SprintSetUpViewController: UITableViewDelegate,
UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskTableViewCell",
                                                 for: indexPath) as! TaskTableViewCell
        if let task = viewModel.task(for: indexPath) {
            cell.viewModel = TaskTableViewCellViewModel(task: task)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { [weak self] (action, indexPath) in
            self?.viewModel.removeTask(index: indexPath)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }

        return [delete]
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0  {
            return "Remaining"
        } else {
            return "Finished"
        }
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 1 { return false }
        return true
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 1 { return false }
        return true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   moveRowAt sourceIndexPath: IndexPath,
                   to destinationIndexPath: IndexPath) {
        viewModel.moveTask(from: sourceIndexPath, to: destinationIndexPath)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
}

extension SprintSetUpViewController {
    struct TableViewUpdates {
        let section: Int
        let deletions: [Int]
        let inserts: [Int]
        let reloads: [Int]
    }

    struct Validation: OptionSet {
        let rawValue: Int

        static let validHours = Validation(rawValue: 1 << 0)
        static let fullyValid: Validation = [.validHours]
    }

    class ViewModel {
        private let viewState = Variable<ViewControllerLifeCycle!>(nil)
        private var validations: Validation = [] {
            didSet {
                taskItEnabledSubject.value = validations.contains(.fullyValid)
            }
        }

        private let tableViewUpdatesSubject = PublishSubject<[TableViewUpdates]>()
        private let unfinishedUpdatesSubject = PublishSubject<TableViewUpdates>()
        private let finishedUpdatesSubject = PublishSubject<TableViewUpdates>()
        private let taskItEnabledSubject = Variable(false)

        private var unfinishedTasks: [Task]
        private var finishedTasks: [Task]
        private var tokensStore = [NotificationToken]()

        private(set) var hoursSelectedInMinutes: Task.Minute?

        private var delayedUiEvents: [() -> Void] = []

        private let realm: DatabaseProxy

        let project: Project

        var unfinishedUpdates: Observable<TableViewUpdates> {
            return unfinishedUpdatesSubject.asObservable()
        }

        var finishedUpdates: Observable<TableViewUpdates> {
            return finishedUpdatesSubject.asObservable()
        }

        var tableViewUpdates: Observable<[TableViewUpdates]> {
            return tableViewUpdatesSubject.asObservable()
        }

        var taskItButtonEnabled: Observable<Bool> {
            return taskItEnabledSubject.asObservable()
        }

        init(project: Project, realm: DatabaseProxy = RealmProxy(instance: .main)) {
            self.project = project
            self.realm = realm

            unfinishedTasks = project.tasks
                .filter("state != \(TaskState.finished.rawValue)")
                .map { $0 }
            finishedTasks = project.tasks
                .filter("state == \(TaskState.finished.rawValue)")
                .map { $0 }

            saveInitialSort()
        }

        func numberOfRowsInSection(section: Int) -> Int {
            return dataSource(for: section)?.count ?? 0
        }

        func numberOfSections() -> Int {
            return 2
        }

        func didUpdateTask(_ task: Task) {
            realm.write(task)
        }

        func insert(newTask: Task) {
            let section: Int
            let row: Int
            let position: Int
            if newTask.state != .finished {
                position = unfinishedTasks.count
                section = 0
                row = unfinishedTasks.count
                unfinishedTasks.append(newTask)

            } else {
                position = unfinishedTasks.count + finishedTasks.count
                section = 1
                row = finishedTasks.count
                finishedTasks.append(newTask)
            }

            realm.write {
                project.tasks.insert(newTask, at: position)
            }

            let update = TableViewUpdates(section: section,
                                          deletions: [],
                                          inserts: [row],
                                          reloads: [])
            updateTableView(with: [update])
        }

        func removeTask(index: IndexPath) {
            if let task = task(for: index) {
                removeFromDataSource(at: index)

                realm.delete(task)
            }
        }

        func moveTask(from original: IndexPath, to destination: IndexPath) {
            if let task = task(for: original) {
                removeFromDataSource(at: original)
                addToDataSource(task: task, path: destination)

                moveProjectTask(from: original, to: destination)
            }
        }

        func task(for path: IndexPath) -> Task? {
            return dataSource(for: path.section)?[path.row]
        }

        func view(_ state: ViewControllerLifeCycle) {
            viewState.value = state

            switch state {
            case .didAppear:
                invalidateTokens()
                purgeUiUpdates()
            default: break
            }
        }

        func didSelectHours(row: Int) {
            hoursSelectedInMinutes = row * 30

            if row == 0 {
                validations.remove(.validHours)
            } else {
                validations.insert(.validHours)
            }
        }

        func watchForUpdates(taskPath: IndexPath) {
            guard let task = task(for: taskPath) else { return }
            let oldState = task.state
            let token = task.observe { [weak self] change in
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    switch change {
                    case .change(let changes):
                        let stateChanges = changes.filter({$0.name == "state"})
                        let reloadCell: () -> Void = {
                            let reload = TableViewUpdates(section: taskPath.section,
                                                          deletions: [],
                                                          inserts: [],
                                                          reloads: [taskPath.row])
                            strongSelf.updateTableView(with: [reload])
                        }

                        guard !stateChanges.isEmpty else {
                            reloadCell()
                            return
                        }

                        let change = stateChanges.first
                        guard let newValue = change?.newValue as? Int,
                            let newState = TaskState(rawValue: newValue)
                            else {
                                reloadCell()
                                return
                        }

                        if oldState == newState {
                            reloadCell()
                        } else if newState == .finished || oldState == .finished {
                            let newSection = newState == .finished ? 1 : 0
                            let newRow = strongSelf.dataSource(for: newSection)!.count

                            strongSelf.moveTask(from: taskPath,
                                                to: IndexPath(row: newRow, section: newSection))

                            let deletion = TableViewUpdates(section: taskPath.section,
                                                            deletions: [taskPath.row],
                                                            inserts: [],
                                                            reloads: [])

                            let insertion = TableViewUpdates(section: newSection,
                                                             deletions: [],
                                                             inserts: [newRow],
                                                             reloads: [])

                            strongSelf.updateTableView(with: [deletion, insertion])
                        } else {
                            reloadCell()
                        }

                    default: break
                    }
                }
            }
            tokensStore.append(token)
        }

        private func dataSource(for section: Int) -> [Task]? {
            switch section {
            case 0: return unfinishedTasks
            case 1: return finishedTasks
            default: return nil
            }
        }

        private func removeFromDataSource(at index: IndexPath) {
            switch index.section {
            case 0: unfinishedTasks.remove(at: index.row)
            case 1: finishedTasks.remove(at: index.row)
            default: break
            }
        }

        private func addToDataSource(task: Task, path: IndexPath) {
            switch path.section {
            case 0: unfinishedTasks.insert(task, at: path.row)
            case 1: finishedTasks.insert(task, at: path.row)
            default: break
            }
        }

        private func updateTableView(with updates: [TableViewUpdates]) {
            guard viewState.value == .didAppear else {
                delayedUiEvents.append({ [weak self] in
                    self?.tableViewUpdatesSubject.onNext(updates)
                })
                return
            }

            tableViewUpdatesSubject.onNext(updates)
        }

        private func saveInitialSort() {
            var indexForIds: [String: Int] = [:]

            for (index, task) in unfinishedTasks.enumerated() {
                indexForIds[task.id] = index
            }

            for (index, task) in finishedTasks.enumerated() {
                indexForIds[task.id] = unfinishedTasks.count + index
            }

            let sorted = unfinishedTasks + finishedTasks

            realm.write {
                let count = project.tasks.count
                project.tasks.replaceSubrange(0..<count, with: sorted)
            }
        }

        private func moveProjectTask(from: IndexPath, to: IndexPath) {
            switch (from.section, to.section) {
            case (0,0):
                realm.write {
                    project.tasks.move(from: from.row, to: to.row)
                }
            case (0,1):
                let offset = unfinishedTasks.count - 1
                realm.write {
                    project.tasks.move(from: from.row, to: offset + to.row)
                }
            case (1,0):
                let offset = unfinishedTasks.count - 1
                realm.write {
                    project.tasks.move(from: offset + from.row, to: to.row)
                }
            default: break
            }
        }

        private func purgeUiUpdates() {
            for update in delayedUiEvents {
                update()
            }
            delayedUiEvents = []
        }

        private func invalidateTokens() {
            for token in tokensStore { token.invalidate() }
            tokensStore = []
        }
    }
}
