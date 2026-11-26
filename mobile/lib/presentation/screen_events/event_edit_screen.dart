import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../models/data_models/gift_event.dart';
import '../../utils/date_fmt.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../../controller/settings_controller.dart';
import '../common_components/components.dart';
import '../common_components/ui_kit.dart';

/// X01 - Tạo / sửa sự kiện. Với lần đầu (`first`) điều hướng sang Home sau khi tạo.
class EventEditScreen extends StatefulWidget {
  const EventEditScreen({super.key});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final EventController _c = Get.find<EventController>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _loc = TextEditingController();
  final TextEditingController _expected = TextEditingController();
  final SettingsController _settings = Get.find<SettingsController>();
  late final Map<String, dynamic> _args =
      (Get.arguments as Map?)?.cast<String, dynamic>() ?? {};
  GiftEvent? _editing;
  String _type = 'wedding';
  DateTime _date = DateTime.now();
  String? _nameErr;
  bool _saving = false;

  bool get _first => _args['first'] == true;

  @override
  void initState() {
    super.initState();
    final id = _args['id'] as String?;
    if (id != null) {
      _editing = _c.events.firstWhereOrNull((e) => e.id == id);
      final e = _editing;
      if (e != null) {
        _name.text = e.name;
        _loc.text = e.location ?? '';
        _type = e.type;
        final n = _settings.expectedFor(e.id);
        if (n > 0) _expected.text = '$n';
        _date = DateTime.tryParse(e.eventDate) ?? DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _loc.dispose();
    _expected.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameErr = 'err_event_name'.tr);
      return;
    }
    setState(() {
      _nameErr = null;
      _saving = true;
    });
    try {
      final saved = await _c.save(
        id: _editing?.id,
        name: name,
        type: _type,
        eventDate: DateFmt.iso(_date),
        location: _loc.text,
      );
      await _settings.setExpected(
        saved.id,
        int.tryParse(_expected.text.trim()) ?? 0,
      );
      Toast.show('saved'.tr);
      if (_first) {
        Get.offAllNamed(RouteName.shell);
      } else {
        Get.back();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => GradientScaffold(
        appBar: _first
            ? AppBar(title: Text('event_first_title'.tr))
            : AppHeader(
                title: _editing == null ? 'event_create'.tr : 'event_edit'.tr,
              ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_first)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'event_first_msg'.tr,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                FieldLabel('event_name'.tr),
                IconField(
                  controller: _name,
                  icon: Icons.celebration_outlined,
                  hint: 'event_name_hint'.tr,
                  errorText: _nameErr,
                ),
                FieldLabel('event_type'.tr),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in EventTypeInfo.all)
                      ChoiceChip(
                        avatar: Text(t.emoji),
                        label: Text(t.labelKey.tr),
                        selected: _type == t.type,
                        onSelected: (_) => setState(() => _type = t.type),
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.chip,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _type == t.type
                              ? Colors.white
                              : AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                FieldLabel('event_date'.tr),
                SoftCard(
                  onTap: _pickDate,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(DateFmt.display(DateFmt.iso(_date))),
                    ],
                  ),
                ),
                FieldLabel('event_location'.tr),
                IconField(
                  controller: _loc,
                  icon: Icons.place_outlined,
                  hint: 'event_location_hint'.tr,
                ),
                FieldLabel('event_expected'.tr),
                IconField(
                  controller: _expected,
                  icon: Icons.mail_outline_rounded,
                  hint: 'event_expected_hint'.tr,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: _editing == null ? 'event_create'.tr : 'save'.tr,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      );
}
