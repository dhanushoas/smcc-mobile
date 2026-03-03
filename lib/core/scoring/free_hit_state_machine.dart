import 'match_state.dart';
import 'scoring_enums.dart';

class FreeHitStateMachine {
  /// 7. FREE HIT STATE MACHINE
  /// Evaluates the next state of isFreeHit based on the previous state and the current delivery.
  static bool getNextFreeHitState(bool currentIsFreeHit, DeliveryType currentDelivery) {
    if (currentDelivery == DeliveryType.noBall) {
      // No Ball always triggers a Free Hit on the NEXT ball.
      return true;
    }

    if (currentIsFreeHit) {
      // We are currently on a free hit ball.
      if (currentDelivery == DeliveryType.wide || currentDelivery == DeliveryType.noBall) {
        // Free Hit continues if the ball was illegal.
        return true;
      }
      
      // Free hit ends if normal, bye, or leg bye
      if (currentDelivery == DeliveryType.normal || 
          currentDelivery == DeliveryType.bye || 
          currentDelivery == DeliveryType.legBye) {
        return false;
      }
    }

    return false;
  }
}
