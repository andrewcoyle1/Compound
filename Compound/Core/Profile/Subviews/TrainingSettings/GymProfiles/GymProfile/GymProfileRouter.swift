import SwiftUI

@MainActor
protocol GymProfileRouter: OnboardingStepRouter {
    func showEditFreeWeightView(freeWeight: Binding<FreeWeights>)
    func showEditLoadableBarView(loadableBar: Binding<LoadableBars>)
    func showEditFixedWeightBarView(fixedWeightBar: Binding<FixedWeightBars>)
    func showEditBandView(band: Binding<Bands>)
    func showEditBodyWeightView(bodyWeight: Binding<BodyWeights>)
    func showEditLoadableAccessoryView(loadableAccessory: Binding<LoadableAccessoryEquipment>)
    func showEditCableMachineView(cableMachine: Binding<CableMachine>)
    func showEditPlateLoadedMachineView(plateLoadedMachine: Binding<PlateLoadedMachine>)
    func showEditPinLoadedMachineView(pinLoadedMachine: Binding<PinLoadedMachine>)
    
}

extension CoreRouter: GymProfileRouter { }
