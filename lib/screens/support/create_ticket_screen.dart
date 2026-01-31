import 'package:flutter/material.dart';
import '../../models/support_ticket.dart';
import '../../services/support_service.dart';

/// Screen to create a new support ticket
class CreateTicketScreen extends StatefulWidget {
  final String userEmail;
  final String userName;

  const CreateTicketScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final SupportService _supportService = SupportService();

  TicketType _selectedType = TicketType.general;
  TicketPriority _selectedPriority = TicketPriority.medium;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final result = await _supportService.createTicket(
      name: widget.userName,
      email: widget.userEmail,
      subject: _subjectController.text.trim(),
      message: _messageController.text.trim(),
      type: _selectedType,
      priority: _selectedPriority,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (result.success) {
        _showSuccessDialog(result.ticketId!);
      } else {
        _showErrorSnackbar(result.errorMessage ?? 'Failed to create ticket');
      }
    }
  }

  void _showSuccessDialog(int ticketId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Ticket Created!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ticket #$ticketId has been submitted successfully. We\'ll get back to you soon!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return to list with refresh
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90A4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Support Ticket',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(
                        0xFF4A90A4,
                      ).withValues(alpha: 0.2),
                      child: Text(
                        widget.userName.isNotEmpty
                            ? widget.userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Color(0xFF4A90A4),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.userEmail,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Type and Priority section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ticket Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTypeSelector(),
                    const SizedBox(height: 20),
                    const Text(
                      'Priority',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPrioritySelector(),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Subject and Message section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subject',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: 'Brief description of your issue',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF4A90A4),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        if (value.trim().length < 5) {
                          return 'Subject must be at least 5 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Message',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Please describe your issue in detail...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF4A90A4),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your message';
                        }
                        if (value.trim().length < 10) {
                          return 'Message must be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90A4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit Ticket',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TicketType.values.map((type) {
        final isSelected = _selectedType == type;
        return ChoiceChip(
          label: Text(type.displayName),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedType = type;
              });
            }
          },
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
          backgroundColor: Colors.grey.shade100,
          selectedColor: const Color(0xFF4A90A4),
          checkmarkColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: TicketPriority.values.map((priority) {
        final isSelected = _selectedPriority == priority;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: priority != TicketPriority.high ? 8 : 0,
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPriority = priority;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? priority.color.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? priority.color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      priority == TicketPriority.low
                          ? Icons.arrow_downward
                          : priority == TicketPriority.medium
                          ? Icons.remove
                          : Icons.arrow_upward,
                      color: isSelected ? priority.color : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priority.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? priority.color
                            : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
