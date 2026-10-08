import SwiftUI

@MainActor
protocol GymProfileRouter: OnboardingStepRouter {
    func showEditFreeWeightView(freeWeight: Binding<FreeWeights>)
    func showEditLoadableBarView(loadableBar: Binding<LoadableBars>)
    func showEditFixedWeightBarView(fixedWeightBar: Binding<FixedWeightBars>)
    func showEditBandView(band: Binding<Bands>)
    func showEditBodyWeightView(bodyWeight: Binding<BodyWeights>)
    func showEditLoadableAccessoryView(loadableAccessory: Binding<LoadableAccessoryEquipment>)
    func showEditStackMachineView<Machine: StackMachine>(machine: Binding<Machine>)
    func showEditPlateLoadedMachineView(plateLoadedMachine: Binding<PlateLoadedMachine>)
    
}

extension CoreRouter: GymProfileRouter { }
