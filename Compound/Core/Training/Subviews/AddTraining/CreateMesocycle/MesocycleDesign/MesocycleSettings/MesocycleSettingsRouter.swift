import SwiftUI

@MainActor
protocol MesocycleSettingsRouter: GlobalRouter {
    func showRenameMesocycleView(delegate: RenameWorkoutTemplateModelDelegate)
    func showEditMesocycleColourIconView(colour: String, icon: String, onSave: @escaping (String, String) -> Void)
    func showEditDayOrderView(dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void)
    func showEditDeloadView(selected: DeloadType, onSave: @escaping (DeloadType) -> Void)
}

extension CoreRouter: MesocycleSettingsRouter {
    func showRenameMesocycleView(delegate: RenameWorkoutTemplateModelDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.renameWorkoutTemplateModelView(router: router, delegate: delegate)
        }
    }

    func showEditMesocycleColourIconView(colour: String, icon: String, onSave: @escaping (String, String) -> Void) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.editMesocycleColourIconView(router: router, colour: colour, icon: icon, onSave: onSave)
        }
    }

    func showEditDayOrderView(dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.editDayOrderView(router: router, dayPlans: dayPlans, onSave: onSave)
        }
    }

    func showEditDeloadView(selected: DeloadType, onSave: @escaping (DeloadType) -> Void) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.editDeloadView(router: router, selected: selected, onSave: onSave)
        }
    }
}
