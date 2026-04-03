import 'package:flutter/foundation.dart';

class CustomerGenerateSelection {
  CustomerGenerateSelection({
    required this.customerId,
    required this.displayName,
    required this.relationshipStage,
  });

  final String customerId;
  final String displayName;
  final String relationshipStage;
}

class CustomerGenerateSelectionStore {
  CustomerGenerateSelectionStore._();

  static final CustomerGenerateSelectionStore instance =
      CustomerGenerateSelectionStore._();

  final ValueNotifier<CustomerGenerateSelection?> selectionNotifier =
      ValueNotifier<CustomerGenerateSelection?>(null);

  CustomerGenerateSelection? get current => selectionNotifier.value;

  void setSelection(CustomerGenerateSelection selection) {
    selectionNotifier.value = selection;
  }

  void clear() {
    selectionNotifier.value = null;
  }
}
