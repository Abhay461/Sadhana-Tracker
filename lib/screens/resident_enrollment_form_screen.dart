// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/notification_helper.dart';

class ResidentEnrollmentFormScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? preacher;
  final VoidCallback onSuccess;

  const ResidentEnrollmentFormScreen({
    super.key,
    required this.profile,
    this.preacher,
    required this.onSuccess,
  });

  @override
  State<ResidentEnrollmentFormScreen> createState() => _ResidentEnrollmentFormScreenState();
}

class _ResidentEnrollmentFormScreenState extends State<ResidentEnrollmentFormScreen> {
  final supabase = Supabase.instance.client;
  int _currentStep = 0;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // STEP 1: General & Personal Info Controllers
  final _residencyNameController = TextEditingController();
  final _referrerController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _educationController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _orgController = TextEditingController();
  final _roleController = TextEditingController();
  DateTime? _dateOfJoining;
  DateTime? _dob;
  String _maritalStatus = 'Single';

  // STEP 2: Address & Emergency Contacts
  final _presentAddressController = TextEditingController();
  final _presentPinController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  final _permanentPinController = TextEditingController();

  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _emergencyEmailController = TextEditingController();
  final _emergencyAddressController = TextEditingController();
  final _emergencyPinController = TextEditingController();

  // STEP 3: Academic & Employment Lists
  final List<Map<String, String>> _academicList = [];
  final List<Map<String, String>> _trainingList = [];
  final List<Map<String, String>> _employmentList = [];

  // Temporary controllers for academic qualification builder dialog
  final _courseController = TextEditingController();
  final _boardController = TextEditingController();
  final _schoolController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _subjectsController = TextEditingController();
  final _percentageController = TextEditingController();

  // Temporary controllers for training dialog
  final _trainCourseController = TextEditingController();
  final _trainConductedController = TextEditingController();
  final _trainDurationController = TextEditingController();
  final _trainYearController = TextEditingController();

  // Temporary controllers for employment dialog
  final _empNameController = TextEditingController();
  final _empPeriodController = TextEditingController();
  final _empDesignationController = TextEditingController();
  final _empAuthorityController = TextEditingController();
  final _empSalaryController = TextEditingController();
  final _empReasonController = TextEditingController();

  // Hobbies, Hobbies controllers
  final _hobbiesController = TextEditingController();
  final _membershipsController = TextEditingController();
  final _publicationsController = TextEditingController();
  final _honorsController = TextEditingController();

  // STEP 4: Spiritual Assessment Controllers
  final Map<String, bool> _vcmSource = {
    'Friends': false,
    'Family': false,
    'Ads': false,
    'Others': false,
  };
  final _vcmSourceOthersController = TextEditingController();
  final _firstVisitVCMController = TextEditingController();
  bool? _visitSinceChildhood;

  final Map<String, bool> _vcmLikes = {
    'Prasadam': false,
    'Cleanliness': false,
    'Kirtans': false,
    'Preaching': false,
    'Others': false,
  };
  final _vcmLikesOthersController = TextEditingController();
  bool? _heardPrabhupada;
  final _firstContactVCMController = TextEditingController();

  final Map<String, bool> _attendedPrograms = {
    'Art of Mind Control': false,
    'Jijnasa': false,
    'Yoga For Happiness': false,
    'Others': false,
  };
  final _attendedProgramsOthersController = TextEditingController();
  final _folkIdController = TextEditingController();
  final _folkGuideController = TextEditingController();
  bool? _renderedServices;
  final _renderedServicesDetailsController = TextEditingController();
  bool? _otherMeditationCourse;
  final _otherMeditationCourseDetailsController = TextEditingController();
  bool? _knowFourPrinciples;
  final _recommendedRoundsController = TextEditingController();
  final _chantingRoundsController = TextEditingController();
  final _chantingDurationYearsController = TextEditingController();
  final _chantingDurationMonthsController = TextEditingController();
  final _chantingOneMalaTimeController = TextEditingController();
  bool? _readPrabhupadaBooks;
  final _prabhupadaBooksDetailsController = TextEditingController();

  // STEP 5: Personal & Lifestyle Assessment Controllers
  final _aimInLifeController = TextEditingController();
  bool? _facedLastingImpactSituation;
  final _lastingImpactSituationDetailsController = TextEditingController();
  final _learningFromSituationController = TextEditingController();
  final _handledSituationController = TextEditingController();
  final _situationOutcomeController = TextEditingController();
  final _motivationKCController = TextEditingController();
  final _motivationResidencyController = TextEditingController();
  bool? _parentsApproved;
  bool? _willParticipateMorningSchedule;
  bool? _hasSpecialSkills;
  final Map<String, bool> _specialSkills = {
    'Singing/dancing': false,
    'Painting/drawing': false,
    'Acting/drama': false,
    'Musical instruments': false,
    'Others': false,
  };
  final _specialSkillsOthersController = TextEditingController();
  final _watchMoviesFrequencyController = TextEditingController();
  final _wakeupTimeController = TextEditingController();
  final _officeCollegeTimingsController = TextEditingController();
  final _luggageDetailsController = TextEditingController();

  // STEP 6: Medical History, Debts, Criminal & Self-Declaration
  final Map<String, bool> _medicalYesNo = {
    'physical_ailment': false,
    'medication': false,
    'mental_illness': false,
    'mental_institution': false,
    'venereal_disease': false,
    'allergic_disease': false,
    'smoke_alcohol': false,
    'non_veg': false,
  };
  final Map<String, TextEditingController> _medicalControllers = {
    'physical_ailment': TextEditingController(),
    'medication': TextEditingController(),
    'mental_illness': TextEditingController(),
    'mental_institution': TextEditingController(),
    'venereal_disease': TextEditingController(),
    'allergic_disease': TextEditingController(),
    'smoke_alcohol': TextEditingController(),
    'non_veg': TextEditingController(),
  };

  final Map<String, bool> _documentsSubmitted = {
    'Passport': false,
    'Aadhar': false,
    'Driving License': false,
    'Voter ID': false,
    'Highest Degree Certificate Copy': false,
    'SSC Certificate Copy': false,
    'Photos': false,
  };

  bool _hasDebts = false;
  final _debtsDetailsController = TextEditingController();
  bool _hasCriminalCharges = false;
  final _criminalDetailsController = TextEditingController();

  bool _acceptedRulesAndTerms = false;
  final _declarationPlaceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.profile['name'] ?? '';
    _mobileController.text = widget.profile['phone'] ?? '';
    _emailController.text = widget.profile['email'] ?? '';
  }

  @override
  void dispose() {
    _residencyNameController.dispose();
    _referrerController.dispose();
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _educationController.dispose();
    _bloodGroupController.dispose();
    _orgController.dispose();
    _roleController.dispose();
    _presentAddressController.dispose();
    _presentPinController.dispose();
    _permanentAddressController.dispose();
    _permanentPinController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _emergencyEmailController.dispose();
    _emergencyAddressController.dispose();
    _emergencyPinController.dispose();

    _courseController.dispose();
    _boardController.dispose();
    _schoolController.dispose();
    _passingYearController.dispose();
    _subjectsController.dispose();
    _percentageController.dispose();
    _trainCourseController.dispose();
    _trainConductedController.dispose();
    _trainDurationController.dispose();
    _trainYearController.dispose();
    _empNameController.dispose();
    _empPeriodController.dispose();
    _empDesignationController.dispose();
    _empAuthorityController.dispose();
    _empSalaryController.dispose();
    _empReasonController.dispose();
    _hobbiesController.dispose();
    _membershipsController.dispose();
    _publicationsController.dispose();
    _honorsController.dispose();

    _vcmSourceOthersController.dispose();
    _firstVisitVCMController.dispose();
    _vcmLikesOthersController.dispose();
    _firstContactVCMController.dispose();
    _attendedProgramsOthersController.dispose();
    _folkIdController.dispose();
    _folkGuideController.dispose();
    _renderedServicesDetailsController.dispose();
    _otherMeditationCourseDetailsController.dispose();
    _recommendedRoundsController.dispose();
    _chantingRoundsController.dispose();
    _chantingDurationYearsController.dispose();
    _chantingDurationMonthsController.dispose();
    _chantingOneMalaTimeController.dispose();
    _prabhupadaBooksDetailsController.dispose();

    _aimInLifeController.dispose();
    _lastingImpactSituationDetailsController.dispose();
    _learningFromSituationController.dispose();
    _handledSituationController.dispose();
    _situationOutcomeController.dispose();
    _motivationKCController.dispose();
    _motivationResidencyController.dispose();
    _specialSkillsOthersController.dispose();
    _watchMoviesFrequencyController.dispose();
    _wakeupTimeController.dispose();
    _officeCollegeTimingsController.dispose();
    _luggageDetailsController.dispose();

    for (var controller in _medicalControllers.values) {
      controller.dispose();
    }
    _debtsDetailsController.dispose();
    _criminalDetailsController.dispose();
    _declarationPlaceController.dispose();

    super.dispose();
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_residencyNameController.text.trim().isEmpty) {
        _showValidationError('FOLK Residency Name is required.');
        return false;
      }
      if (_dateOfJoining == null) {
        _showValidationError('Date of Joining is required.');
        return false;
      }
      if (_fullNameController.text.trim().isEmpty) {
        _showValidationError('Full Name is required.');
        return false;
      }
      if (_mobileController.text.trim().isEmpty) {
        _showValidationError('Mobile Number is required.');
        return false;
      }
      if (_emailController.text.trim().isEmpty) {
        _showValidationError('E-mail ID is required.');
        return false;
      }
      if (_educationController.text.trim().isEmpty) {
        _showValidationError('Educational Qualification is required.');
        return false;
      }
    } else if (_currentStep == 1) {
      if (_presentAddressController.text.trim().isEmpty) {
        _showValidationError('Present Address is required.');
        return false;
      }
      if (_presentPinController.text.trim().isEmpty) {
        _showValidationError('Present Pin Code is required.');
        return false;
      }
      if (_permanentAddressController.text.trim().isEmpty) {
        _showValidationError('Permanent Address is required.');
        return false;
      }
      if (_permanentPinController.text.trim().isEmpty) {
        _showValidationError('Permanent Pin Code is required.');
        return false;
      }
      if (_emergencyNameController.text.trim().isEmpty) {
        _showValidationError('Emergency Contact Name is required.');
        return false;
      }
      if (_emergencyPhoneController.text.trim().isEmpty) {
        _showValidationError('Emergency Contact phone number is required.');
        return false;
      }
      if (_emergencyRelationController.text.trim().isEmpty) {
        _showValidationError('Emergency Relationship is required.');
        return false;
      }
    }
    return true;
  }

  void _showValidationError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || !_validateCurrentStep()) {
      return;
    }

    if (_dateOfJoining == null) {
      _showValidationError('Please specify a Date of Joining in Step 1!');
      return;
    }

    if (!_acceptedRulesAndTerms) {
      _showValidationError('You must accept the Rules and Terms in the final step!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> formData = {
        'program': 'Yoga For Happiness Residential Program',
        'folk_residency_name': _residencyNameController.text.trim(),
        'referrer': _referrerController.text.trim(),
        'date_of_joining': DateFormat('yyyy-MM-dd').format(_dateOfJoining!),
        'personal': {
          'full_name': _fullNameController.text.trim(),
          'mobile_no': _mobileController.text.trim(),
          'dob': _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '',
          'email': _emailController.text.trim(),
          'education': _educationController.text.trim(),
          'marital_status': _maritalStatus,
          'blood_group': _bloodGroupController.text.trim(),
          'org_or_college': _orgController.text.trim(),
          'role_or_course': _roleController.text.trim(),
        },
        'address': {
          'present_address': _presentAddressController.text.trim(),
          'present_pin': _presentPinController.text.trim(),
          'permanent_address': _permanentAddressController.text.trim(),
          'permanent_pin': _permanentPinController.text.trim(),
        },
        'emergency': {
          'name': _emergencyNameController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
          'relation': _emergencyRelationController.text.trim(),
          'email': _emergencyEmailController.text.trim(),
          'address': _emergencyAddressController.text.trim(),
          'pin': _emergencyPinController.text.trim(),
        },
        'academic': _academicList,
        'training': _trainingList,
        'employment': _employmentList,
        'hobbies_and_activities': {
          'hobbies': _hobbiesController.text.trim(),
          'professional_memberships': _membershipsController.text.trim(),
          'publications': _publicationsController.text.trim(),
          'honors_and_scholarships': _honorsController.text.trim(),
        },
        'spiritual_assessment': {
          'vcm_source': _vcmSource.entries.where((e) => e.value).map((e) => e.key).toList(),
          'vcm_source_others': _vcmSourceOthersController.text.trim(),
          'first_visit_vcm': _firstVisitVCMController.text.trim(),
          'visit_since_childhood': _visitSinceChildhood,
          'vcm_likes': _vcmLikes.entries.where((e) => e.value).map((e) => e.key).toList(),
          'vcm_likes_others': _vcmLikesOthersController.text.trim(),
          'heard_prabhupada': _heardPrabhupada,
          'first_contact_vcm': _firstContactVCMController.text.trim(),
          'attended_programs': _attendedPrograms.entries.where((e) => e.value).map((e) => e.key).toList(),
          'attended_programs_others': _attendedProgramsOthersController.text.trim(),
          'folk_id': _folkIdController.text.trim(),
          'folk_guide': _folkGuideController.text.trim(),
          'rendered_services': _renderedServices,
          'rendered_services_details': _renderedServicesDetailsController.text.trim(),
          'other_meditation_course': _otherMeditationCourse,
          'other_meditation_course_details': _otherMeditationCourseDetailsController.text.trim(),
          'know_four_principles': _knowFourPrinciples,
          'recommended_rounds': _recommendedRoundsController.text.trim(),
          'chanting_rounds': _chantingRoundsController.text.trim(),
          'chanting_duration_years': _chantingDurationYearsController.text.trim(),
          'chanting_duration_months': _chantingDurationMonthsController.text.trim(),
          'chanting_one_mala_time': _chantingOneMalaTimeController.text.trim(),
          'read_prabhupada_books': _readPrabhupadaBooks,
          'prabhupada_books_details': _prabhupadaBooksDetailsController.text.trim(),
        },
        'lifestyle_assessment': {
          'aim_in_life': _aimInLifeController.text.trim(),
          'faced_lasting_impact_situation': _facedLastingImpactSituation,
          'lasting_impact_situation_details': _lastingImpactSituationDetailsController.text.trim(),
          'learning_from_situation': _learningFromSituationController.text.trim(),
          'handled_situation': _handledSituationController.text.trim(),
          'situation_outcome': _situationOutcomeController.text.trim(),
          'motivation_kc': _motivationKCController.text.trim(),
          'motivation_residency': _motivationResidencyController.text.trim(),
          'parents_approved': _parentsApproved,
          'will_participate_morning_schedule': _willParticipateMorningSchedule,
          'has_special_skills': _hasSpecialSkills,
          'special_skills': _specialSkills.entries.where((e) => e.value).map((e) => e.key).toList(),
          'special_skills_others': _specialSkillsOthersController.text.trim(),
          'watch_movies_frequency': _watchMoviesFrequencyController.text.trim(),
          'wakeup_time': _wakeupTimeController.text.trim(),
          'office_college_timings': _officeCollegeTimingsController.text.trim(),
          'luggage_details': _luggageDetailsController.text.trim(),
        },
        'medical_history': {
          for (var key in _medicalYesNo.keys)
            key: {
              'has_condition': _medicalYesNo[key],
              'details': _medicalControllers[key]!.text.trim(),
            }
        },
        'documents_submitted': _documentsSubmitted.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
        'debts': {
          'has_debts': _hasDebts,
          'details': _debtsDetailsController.text.trim(),
        },
        'criminal': {
          'has_charges': _hasCriminalCharges,
          'details': _criminalDetailsController.text.trim(),
        },
        'self_declaration': {
          'accepted_rules_and_terms': _acceptedRulesAndTerms,
          'declaration_place': _declarationPlaceController.text.trim(),
          'declaration_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        }
      };

      final jsonString = jsonEncode(formData);

      final updateData = {
        'worker_id': widget.profile['id'],
        'worker_name': widget.profile['name'],
        'preacher_name': widget.preacher?['name'] ?? 'Preacher',
        'category': 'residency_admission',
        'work_started': 'Residency Admission Request',
        'description': 'Student requested residency admission.',
        'work_completed': '',
        'is_completed': false,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'points': 0,
      };
      await supabase.from('updates').insert({
        ...updateData,
        'description': jsonString, // store full JSON in database
      });
      NotificationHelper.sendUpdateNotification(updateData).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comprehensive Residency Enrolment submitted successfully!'), backgroundColor: Colors.green),
        );
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving enrollment form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit form: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, {IconData? icon, String? Function(String?)? validator, TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF0284C7)) : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0284C7))),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, VoidCallback onTap, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0284C7)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value == null ? label : DateFormat('dd MMM yyyy').format(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: value == null ? FontWeight.normal : FontWeight.bold,
                    color: value == null ? Colors.grey[600] : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYesNoField(String label, bool? value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: value == true ? const Color(0xFF0284C7) : Colors.transparent,
                    foregroundColor: value == true ? Colors.white : const Color(0xFF64748B),
                    side: BorderSide(color: value == true ? const Color(0xFF0284C7) : Colors.grey[200]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => onChanged(true),
                  child: const Text('Yes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: value == false ? const Color(0xFF0284C7) : Colors.transparent,
                    foregroundColor: value == false ? Colors.white : const Color(0xFF64748B),
                    side: BorderSide(color: value == false ? const Color(0xFF0284C7) : Colors.grey[200]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => onChanged(false),
                  child: const Text('No', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectCard(String label, Map<String, bool> options, {TextEditingController? othersController, String? othersKey = 'Others'}) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.keys.map((key) {
                final isSelected = options[key] ?? false;
                return ChoiceChip(
                  label: Text(key),
                  selected: isSelected,
                  selectedColor: const Color(0xFFE0F2FE),
                  checkmarkColor: const Color(0xFF0284C7),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF475569),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    setState(() {
                      options[key] = val;
                    });
                  },
                );
              }).toList(),
            ),
            if (othersController != null && othersKey != null && (options[othersKey] ?? false)) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: othersController,
                decoration: InputDecoration(
                  labelText: 'Please specify...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalQuestion(String key, String question) {
    final yes = _medicalYesNo[key] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYesNoField(question, yes, (val) {
          setState(() {
            _medicalYesNo[key] = val;
          });
        }),
        if (yes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TextField(
              controller: _medicalControllers[key],
              decoration: InputDecoration(
                hintText: 'Please specify medical details...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        const Divider(height: 16),
      ],
    );
  }

  void _addAcademicQualification() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Academic Qualification', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_courseController, 'Course (e.g. B.Tech, 12th)'),
                _buildTextField(_boardController, 'University / Board'),
                _buildTextField(_schoolController, 'School / College / Institution'),
                _buildTextField(_passingYearController, 'Year of Passing', keyboardType: TextInputType.number),
                _buildTextField(_subjectsController, 'Main Subjects'),
                _buildTextField(_percentageController, 'Percentage (%)', keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_courseController.text.isEmpty) return;
                setState(() {
                  _academicList.add({
                    'course': _courseController.text,
                    'board': _boardController.text,
                    'institution': _schoolController.text,
                    'year': _passingYearController.text,
                    'subjects': _subjectsController.text,
                    'percentage': _percentageController.text,
                  });
                  _courseController.clear();
                  _boardController.clear();
                  _schoolController.clear();
                  _passingYearController.clear();
                  _subjectsController.clear();
                  _percentageController.clear();
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addTrainingCourse() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Training Course', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_trainCourseController, 'Course'),
                _buildTextField(_trainConductedController, 'Conducted By'),
                _buildTextField(_trainDurationController, 'Duration (e.g. 3 Months)'),
                _buildTextField(_trainYearController, 'Year of Completion', keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_trainCourseController.text.isEmpty) return;
                setState(() {
                  _trainingList.add({
                    'course': _trainCourseController.text,
                    'conducted_by': _trainConductedController.text,
                    'duration': _trainDurationController.text,
                    'year': _trainYearController.text,
                  });
                  _trainCourseController.clear();
                  _trainConductedController.clear();
                  _trainDurationController.clear();
                  _trainYearController.clear();
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addEmployment() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Employment Detail', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_empNameController, 'Employer Name & Contact'),
                _buildTextField(_empPeriodController, 'Period (e.g. 2021-2023)'),
                _buildTextField(_empDesignationController, 'Designation'),
                _buildTextField(_empAuthorityController, 'Reporting Authority'),
                _buildTextField(_empSalaryController, 'Salary (LPA)', keyboardType: TextInputType.number),
                _buildTextField(_empReasonController, 'Reason for Leaving'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_empNameController.text.isEmpty) return;
                setState(() {
                  _employmentList.add({
                    'employer': _empNameController.text,
                    'period': _empPeriodController.text,
                    'designation': _empDesignationController.text,
                    'authority': _empAuthorityController.text,
                    'salary': _empSalaryController.text,
                    'reason': _empReasonController.text,
                  });
                  _empNameController.clear();
                  _empPeriodController.clear();
                  _empDesignationController.clear();
                  _empAuthorityController.clear();
                  _empSalaryController.clear();
                  _empReasonController.clear();
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_residencyNameController, 'FOLK Residency Name * (e.g. VCM Residency)', icon: Icons.home_work_outlined),
        _buildDatePicker('Date of Joining *', _dateOfJoining, () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 7)),
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) setState(() => _dateOfJoining = picked);
        }, Icons.calendar_today),
        _buildTextField(_referrerController, 'How did you know about FOLK Residency?', icon: Icons.help_outline),
        _buildTextField(_fullNameController, 'Full Name (Capital letters) *', icon: Icons.person_outline),
        _buildTextField(_mobileController, 'Mobile No *', icon: Icons.phone_android, keyboardType: TextInputType.phone),
        _buildDatePicker('Date of Birth', _dob, () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().subtract(const Duration(days: 7300)),
            firstDate: DateTime.now().subtract(const Duration(days: 36500)),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _dob = picked);
        }, Icons.cake_outlined),
        _buildTextField(_emailController, 'E-mail ID *', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        _buildTextField(_educationController, 'Educational Qualification *', icon: Icons.school_outlined),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              const Text('Marital Status: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(width: 16),
              const Text('Single'),
              Radio<String>(
                value: 'Single',
                groupValue: _maritalStatus,
                onChanged: (val) => setState(() => _maritalStatus = val ?? 'Single'),
              ),
              const Text('Married'),
              Radio<String>(
                value: 'Married',
                groupValue: _maritalStatus,
                onChanged: (val) => setState(() => _maritalStatus = val ?? 'Married'),
              ),
            ],
          ),
        ),
        
        _buildTextField(_bloodGroupController, 'Blood Group', icon: Icons.bloodtype_outlined),
        _buildTextField(_orgController, 'Presently studying in / working with', icon: Icons.business_outlined),
        _buildTextField(_roleController, 'Designation / Course', icon: Icons.badge_outlined),
      ],
    );
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Present Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
        const SizedBox(height: 8),
        _buildTextField(_presentAddressController, 'Address Details *', maxLines: 2),
        _buildTextField(_presentPinController, 'Pin Code *', keyboardType: TextInputType.number),
        
        const Divider(height: 24),
        const Text('Permanent Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
        const SizedBox(height: 8),
        _buildTextField(_permanentAddressController, 'Address Details *', maxLines: 2),
        _buildTextField(_permanentPinController, 'Pin Code *', keyboardType: TextInputType.number),

        const Divider(height: 24),
        const Text('Emergency Contact Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
        const SizedBox(height: 8),
        _buildTextField(_emergencyNameController, 'Name *', icon: Icons.person_outline),
        _buildTextField(_emergencyPhoneController, 'Contact No *', icon: Icons.phone_android, keyboardType: TextInputType.phone),
        _buildTextField(_emergencyRelationController, 'Relationship *', icon: Icons.family_restroom),
        _buildTextField(_emergencyEmailController, 'Email ID', icon: Icons.email_outlined),
        _buildTextField(_emergencyAddressController, 'Emergency Contact Address', icon: Icons.location_on_outlined, maxLines: 2),
        _buildTextField(_emergencyPinController, 'Pin Code', keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildAcademicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Academic Qualifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
            TextButton.icon(
              onPressed: _addAcademicQualification,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Course', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (_academicList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No qualifications added yet.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _academicList.length,
            itemBuilder: (context, idx) {
              final item = _academicList[idx];
              return Card(
                color: Colors.white,
                child: ListTile(
                  title: Text(item['course'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${item['institution']} | ${item['year']} | ${item['percentage']}%', style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => _academicList.removeAt(idx)),
                  ),
                ),
              );
            },
          ),
        
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Training Courses Attended', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
            TextButton.icon(
              onPressed: _addTrainingCourse,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Training', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (_trainingList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No courses added yet.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _trainingList.length,
            itemBuilder: (context, idx) {
              final item = _trainingList[idx];
              return Card(
                color: Colors.white,
                child: ListTile(
                  title: Text(item['course'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${item['conducted_by']} | Duration: ${item['duration']} | Year: ${item['year']}', style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => _trainingList.removeAt(idx)),
                  ),
                ),
              );
            },
          ),

        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Employment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
            TextButton.icon(
              onPressed: _addEmployment,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Employment', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (_employmentList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No employment records added.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _employmentList.length,
            itemBuilder: (context, idx) {
              final item = _employmentList[idx];
              return Card(
                color: Colors.white,
                child: ListTile(
                  title: Text(item['employer'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${item['designation']} | ${item['period']} | ${item['salary']} LPA', style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => _employmentList.removeAt(idx)),
                  ),
                ),
              );
            },
          ),

        const Divider(height: 24),
        _buildTextField(_hobbiesController, 'Hobbies / Extracurricular Activities'),
        _buildTextField(_membershipsController, 'Membership in Professional Bodies'),
        _buildTextField(_publicationsController, 'Papers & Publications Presented'),
        _buildTextField(_honorsController, 'Honors & Scholarships'),
      ],
    );
  }

  Widget _buildSpiritualStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SPIRITUAL ASSESSMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0284C7))),
        const SizedBox(height: 12),
        _buildMultiSelectCard('1. How did you first come to know about VCM?', _vcmSource, othersController: _vcmSourceOthersController, othersKey: 'Others'),
        _buildTextField(_firstVisitVCMController, '2. When did you first visit VCM?'),
        _buildYesNoField('3. Have you been visiting VCM since childhood?', _visitSinceChildhood, (val) => setState(() => _visitSinceChildhood = val)),
        _buildMultiSelectCard('4. What do you like the most in VCM?', _vcmLikes, othersController: _vcmLikesOthersController, othersKey: 'Others'),
        _buildYesNoField('5. Have you heard of Srila Prabhupada earlier?', _heardPrabhupada, (val) => setState(() => _heardPrabhupada = val)),
        _buildTextField(_firstContactVCMController, '6. Who was your first contact in VCM & when?'),
        _buildMultiSelectCard('7. Mention the programs you have attended/attending in VCM:', _attendedPrograms, othersController: _attendedProgramsOthersController, othersKey: 'Others'),
        
        Row(
          children: [
            Expanded(child: _buildTextField(_folkIdController, 'FOLK ID')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_folkGuideController, 'FOLK Guide')),
          ],
        ),

        _buildYesNoField('9. Have you rendered any services during festivals or weekends at VCM?', _renderedServices, (val) => setState(() => _renderedServices = val)),
        if (_renderedServices == true)
          _buildTextField(_renderedServicesDetailsController, 'Specify services rendered', maxLines: 2),

        _buildYesNoField('10. Have you attended any other course/seminar on spirituality or meditation?', _otherMeditationCourse, (val) => setState(() => _otherMeditationCourse = val)),
        if (_otherMeditationCourse == true)
          _buildTextField(_otherMeditationCourseDetailsController, 'Specify courses/seminars', maxLines: 2),

        _buildYesNoField('11. Do you know the 4 regulative principles given by Srila Prabhupada?\n(No meat eating, No gambling, No intoxication, No illicit sex)', _knowFourPrinciples, (val) => setState(() => _knowFourPrinciples = val)),
        _buildTextField(_recommendedRoundsController, '12. How many rounds of Hare Krishna maha-mantra did Srila Prabhupada recommend one to chant daily?', keyboardType: TextInputType.number),
        
        const Text('13. Daily Chanting details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        _buildTextField(_chantingRoundsController, 'How many rounds do you chant every day?', keyboardType: TextInputType.number),
        Row(
          children: [
            Expanded(child: _buildTextField(_chantingDurationYearsController, 'Chanting since (Years)', keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_chantingDurationMonthsController, 'Months', keyboardType: TextInputType.number)),
          ],
        ),
        _buildTextField(_chantingOneMalaTimeController, 'Time taken for completing 1 mala of Hare Krishna mantra? (e.g. 7-8 mins)'),

        _buildYesNoField('14. Have you read any books authored by Prabhupada?', _readPrabhupadaBooks, (val) => setState(() => _readPrabhupadaBooks = val)),
        if (_readPrabhupadaBooks == true)
          _buildTextField(_prabhupadaBooksDetailsController, 'Specify the names of books read', maxLines: 2),
      ],
    );
  }

  Widget _buildLifestyleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PERSONAL & LIFESTYLE INFO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0284C7))),
        const SizedBox(height: 12),
        _buildTextField(_aimInLifeController, '1. What is your aim in life?', maxLines: 2),
        
        _buildYesNoField('2. Have you faced any situation which had a lasting impact on you?', _facedLastingImpactSituation, (val) => setState(() => _facedLastingImpactSituation = val)),
        if (_facedLastingImpactSituation == true) ...[
          _buildTextField(_lastingImpactSituationDetailsController, 'Please specify the situation', maxLines: 2),
          _buildTextField(_learningFromSituationController, '3. What is your learning from that situation?', maxLines: 2),
          _buildTextField(_handledSituationController, '4. How did you handle that situation?', maxLines: 2),
          _buildTextField(_situationOutcomeController, '5. Have you come out stronger/weaker from that situation?', maxLines: 1),
        ],

        _buildTextField(_motivationKCController, '6. What motivated you to take up Krishna Consciousness seriously?', maxLines: 2),
        _buildTextField(_motivationResidencyController, '7. What motivated you to join FOLK Residency?', maxLines: 2),

        _buildYesNoField('8. Have your parents approved your decision of joining FOLK Residency?', _parentsApproved, (val) => setState(() => _parentsApproved = val)),
        _buildYesNoField('9. Will you happily participate in FOLK Residency\'s 1 hour morning schedule? (like arati, meditation etc.)', _willParticipateMorningSchedule, (val) => setState(() => _willParticipateMorningSchedule = val)),
        
        _buildYesNoField('10. Do you possess any special skill/talent you would like to showcase in FOLK Residency?', _hasSpecialSkills, (val) => setState(() => _hasSpecialSkills = val)),
        if (_hasSpecialSkills == true)
          _buildMultiSelectCard('Select skills/talents:', _specialSkills, othersController: _specialSkillsOthersController, othersKey: 'Others'),

        _buildTextField(_watchMoviesFrequencyController, '11. How frequently do you watch movies / TV?'),
        _buildTextField(_wakeupTimeController, '12. What time do you generally wake up in the morning?'),
        _buildTextField(_officeCollegeTimingsController, '13. Office / college timings:'),
        _buildTextField(_luggageDetailsController, '14. Specify your luggage you will be carrying to FOLK Residency:', maxLines: 2),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Documents Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
        const SizedBox(height: 8),
        ..._documentsSubmitted.keys.map((key) {
          return CheckboxListTile(
            title: Text(key, style: const TextStyle(fontSize: 13)),
            value: _documentsSubmitted[key],
            onChanged: (val) => setState(() => _documentsSubmitted[key] = val ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),

        const Divider(height: 24),
        const Text('Medical History Questionnaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
        const SizedBox(height: 12),
        _buildMedicalQuestion('physical_ailment', 'Do you suffer from any physical ailment?'),
        _buildMedicalQuestion('medication', 'Are you undergoing any kind of medication?'),
        _buildMedicalQuestion('mental_illness', 'Do you have any history of mental / emotional illness?'),
        _buildMedicalQuestion('mental_institution', 'Have you been ever admitted to a mental institution?'),
        _buildMedicalQuestion('venereal_disease', 'Do you suffer from any venereal disease?'),
        _buildMedicalQuestion('allergic_disease', 'Do you suffer from skin/any other allergic disease?'),
        _buildMedicalQuestion('smoke_alcohol', 'Do you smoke / consume alcohol?'),
        _buildMedicalQuestion('non_veg', 'Do you eat non-vegetarian food?'),

        const Divider(height: 24),
        const Text('Additional Declarations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
        const SizedBox(height: 12),
        _buildYesNoField('Do you have any financial debts/obligations?', _hasDebts, (val) => setState(() => _hasDebts = val)),
        if (_hasDebts)
          _buildTextField(_debtsDetailsController, 'Please specify debts details & amount...'),

        _buildYesNoField('Are there any criminal/civil charges or court proceedings against you?', _hasCriminalCharges, (val) => setState(() => _hasCriminalCharges = val)),
        if (_hasCriminalCharges)
          _buildTextField(_criminalDetailsController, 'Please specify case details...'),

        const Divider(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ANNEXURE 1: General Rules of Residency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309))),
              const SizedBox(height: 8),
              const Text(
                '1) Mandatory to attend morning sadhana program every day.\n'
                '2) Mandatory to chant at least 4 rounds of Hare Krishna maha-mantra on beads every day.\n'
                '3) Mandatory to read Srila Prabhupada\'s books for at least 30 minutes daily.\n'
                '4) Mandatory to perform 4 hours of practical devotional service on at least 2 Sundays of every month.\n'
                '5) Maintain clean environment and follow strictly the 4 regulative principles (No meat eating, no gambling, no intoxication, no illicit sex).\n'
                '6) Prior authorization required for leaving or bringing guests/family members.',
                style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text('TERMS & CONDITIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
              const SizedBox(height: 6),
              const Text(
                '• Information provided must be authentic. False claims are grounds for immediate expulsion.\n'
                '• Residents are solely responsible for the safety of their own valuables and belongings.\n'
                '• Copying or retaining books/items belonging to FOLK Residency without permission is strictly prohibited.',
                style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        CheckboxListTile(
          title: Text(
            'I, ${_fullNameController.text.toUpperCase()}, do hereby solemnly affirm & declare that I have read, understood and agree to abide by the General Rules and Terms & Conditions of FOLK Residency.',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          value: _acceptedRulesAndTerms,
          onChanged: (val) => setState(() => _acceptedRulesAndTerms = val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        _buildTextField(_declarationPlaceController, 'Place of Signing *', validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null),
      ],
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal Info';
      case 1:
        return 'Address Details';
      case 2:
        return 'Academic & Employment';
      case 3:
        return 'Spiritual Assessment';
      case 4:
        return 'Lifestyle Info';
      case 5:
        return 'Declarations & Rules';
      default:
        return '';
    }
  }

  Widget _getStepContent(int step) {
    switch (step) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildAddressStep();
      case 2:
        return _buildAcademicStep();
      case 3:
        return _buildSpiritualStep();
      case 4:
        return _buildLifestyleStep();
      case 5:
        return _buildConfirmStep();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Resident Enrollment Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Custom Top Progress Tracker
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getStepTitle(_currentStep).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'Step ${_currentStep + 1} of 6',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / 6,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content Pane
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _getStepContent(_currentStep),
                  ),
                ),
                
                // Bottom control actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() => _currentStep--);
                            },
                            child: const Text(
                              'BACK',
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (_currentStep < 5) {
                              if (_validateCurrentStep()) {
                                setState(() => _currentStep++);
                              }
                            } else {
                              _submitForm();
                            }
                          },
                          child: Text(
                            _currentStep == 5 ? 'SUBMIT ENROLMENT' : 'CONTINUE',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
