import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

/// Settings screen for API key configuration (OpenAI and Google Places)
class ApiKeysSettingsScreen extends StatelessWidget {
  const ApiKeysSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            children: [
              _AIGuidanceSettings(settingsProvider: settingsProvider),
              const Divider(height: 1),
              _GooglePlacesSettings(settingsProvider: settingsProvider),
            ],
          );
        },
      ),
    );
  }
}

class _AIGuidanceSettings extends StatefulWidget {
  final SettingsProvider settingsProvider;

  const _AIGuidanceSettings({required this.settingsProvider});

  @override
  State<_AIGuidanceSettings> createState() => _AIGuidanceSettingsState();
}

class _AIGuidanceSettingsState extends State<_AIGuidanceSettings> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isValidating = false;
  String? _validationMessage;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _isValid = widget.settingsProvider.hasValidOpenAIKey;
    if (_isValid) {
      _validationMessage = 'API key configured';
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _validationMessage = 'Please enter an API key';
        _isValid = false;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationMessage = null;
    });

    try {
      final isValid = await widget.settingsProvider.updateOpenAIApiKey(apiKey);
      if (isValid) {
        setState(() {
          _isValid = true;
          _validationMessage = 'API key validated and saved';
          _apiKeyController.clear();
        });
      } else {
        setState(() {
          _isValid = false;
          _validationMessage =
              'Invalid API key. Please check your key and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationMessage = 'Invalid API key: $e';
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _removeKey() async {
    await widget.settingsProvider.removeOpenAIApiKey();
    setState(() {
      _isValid = false;
      _validationMessage = null;
      _apiKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: Icon(
        Icons.auto_awesome,
        color: _isValid ? Colors.green : null,
      ),
      title: const Text(
        'AI Guidance',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(_isValid
          ? 'API key configured - Filter POIs with AI'
          : 'Configure OpenAI API key for semantic filtering'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Use AI to filter attractions by themes like "romantic", "kid-friendly", or "historical".',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Model:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _OpenAIModels.models.any((m) =>
                              m.id == widget.settingsProvider.openaiModel)
                          ? widget.settingsProvider.openaiModel
                          : 'gpt-4o-mini',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _OpenAIModels.models.map((model) {
                        return DropdownMenuItem(
                          value: model.id,
                          child: Text('${model.name} ${model.priceIndicator}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          Future.microtask(() {
                            widget.settingsProvider.updateOpenAIModel(value);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isValid)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validationMessage ?? 'API key configured',
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI API Key',
                    hintText: 'sk-...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                if (_validationMessage != null)
                  Card(
                    color: _isValid ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(
                            _isValid ? Icons.check_circle : Icons.error,
                            color: _isValid
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationMessage!,
                              style: TextStyle(
                                color: _isValid
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (_isValid)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _removeKey,
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isValidating ? null : _validateAndSave,
                        icon: _isValidating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isValidating ? 'Validating...' : 'Validate & Save',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Get your API key from platform.openai.com • 50 requests/day limit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// OpenAI model information
class _OpenAIModelInfo {
  final String id;
  final String name;
  final String priceIndicator;

  const _OpenAIModelInfo({
    required this.id,
    required this.name,
    required this.priceIndicator,
  });
}

/// Available OpenAI models with pricing
class _OpenAIModels {
  static const List<_OpenAIModelInfo> models = [
    _OpenAIModelInfo(
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      priceIndicator: r'$',
    ),
    _OpenAIModelInfo(
      id: 'gpt-4o',
      name: 'GPT-4o',
      priceIndicator: r'$$',
    ),
    _OpenAIModelInfo(
      id: 'gpt-4-turbo',
      name: 'GPT-4 Turbo',
      priceIndicator: r'$$$',
    ),
    _OpenAIModelInfo(
      id: 'gpt-3.5-turbo',
      name: 'GPT-3.5 Turbo',
      priceIndicator: r'$',
    ),
    _OpenAIModelInfo(
      id: 'o1-mini',
      name: 'O1 Mini',
      priceIndicator: r'$$',
    ),
    _OpenAIModelInfo(
      id: 'o1',
      name: 'O1',
      priceIndicator: r'$$$$',
    ),
  ];
}

class _GooglePlacesSettings extends StatefulWidget {
  final SettingsProvider settingsProvider;

  const _GooglePlacesSettings({required this.settingsProvider});

  @override
  State<_GooglePlacesSettings> createState() => _GooglePlacesSettingsState();
}

class _GooglePlacesSettingsState extends State<_GooglePlacesSettings> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isValidating = false;
  String? _validationMessage;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _isValid = widget.settingsProvider.hasValidGooglePlacesKey;
    if (_isValid) {
      _validationMessage = 'API key configured';
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _validationMessage = 'Please enter an API key';
        _isValid = false;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationMessage = null;
    });

    try {
      final isValid =
          await widget.settingsProvider.updateGooglePlacesApiKey(apiKey);
      if (isValid) {
        setState(() {
          _isValid = true;
          _validationMessage =
              'API key saved! Other POI providers have been auto-disabled (you can re-enable them if needed).';
          _apiKeyController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Google Places enabled. Other providers auto-disabled.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isValid = false;
          _validationMessage =
              'Invalid API key format. Keys should start with "AIza" and be 30-50 characters.';
        });
      }
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationMessage = 'Validation error: $e';
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _removeKey() async {
    await widget.settingsProvider.removeGooglePlacesApiKey();
    setState(() {
      _isValid = false;
      _validationMessage = null;
      _apiKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestCount = widget.settingsProvider.googlePlacesRequestCount;

    return ExpansionTile(
      initiallyExpanded: true,
      leading: Icon(
        Icons.place,
        color: _isValid ? Colors.green : null,
      ),
      title: const Text(
        'Google Places',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(_isValid
          ? 'API key configured - Premium POI data'
          : 'Configure API key for rich place data'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Google Places provides rich POI data including ratings, reviews, and photos.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.paid, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a paid API. Google provides \$200/month free credit. Monitor usage in Google Cloud Console.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_isValid) ...[
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationMessage ?? 'API key configured',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Requests this month: $requestCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Google Places API Key',
                    hintText: 'AIza...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                if (_validationMessage != null)
                  Card(
                    color: _isValid ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(
                            _isValid ? Icons.check_circle : Icons.error,
                            color: _isValid
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationMessage!,
                              style: TextStyle(
                                color: _isValid
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (_isValid)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _removeKey,
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isValidating ? null : _validateAndSave,
                        icon: _isValidating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isValidating ? 'Validating...' : 'Validate & Save',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Get your API key from console.cloud.google.com and enable Places API',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
