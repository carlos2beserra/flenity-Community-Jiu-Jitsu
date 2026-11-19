import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ui/widgets/common.dart';
import '../media_picker.dart';
import '../social_models.dart';
import '../widgets/social_ui.dart';

/// Edição da foto de perfil e da bio. Fecha com `true` quando algo foi salvo.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final SocialProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _bio = TextEditingController(text: widget.profile.bio);
  late SocialAuthor _author = widget.profile.author;
  bool _busy = false;
  bool _changed = false;

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final picker = Provider.of<MediaPickerService?>(context, listen: false) ?? DeviceMediaPicker();
    final api = socialApiOf(context);
    try {
      final picked = await picker.pickFromGallery(multiple: false, allowVideo: false, videoOnly: false);
      if (picked.isEmpty || !mounted) return;
      setState(() => _busy = true);
      final media = await api.upload(picked.first.bytes, picked.first.name);
      final profile = await api.updateProfile(avatarMediaId: media.id);
      if (!mounted) return;
      setState(() {
        _author = profile.author;
        _changed = true;
      });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    try {
      final profile = await socialApiOf(context).updateProfile(avatarMediaId: '');
      if (!mounted) return;
      setState(() {
        _author = profile.author;
        _changed = true;
      });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await socialApiOf(context).updateProfile(bio: _bio.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, errorText(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(_changed);
    },
    child: Scaffold(
      backgroundColor: SocialColors.bg,
      appBar: AppBar(
        backgroundColor: SocialColors.bg,
        title: Text('Editar perfil', style: socialTitleStyle.copyWith(fontSize: 18)),
        actions: [
          TextButton(
            key: const Key('edit-profile-save'),
            onPressed: _busy ? null : _save,
            child: const Text('Concluir', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          Center(child: SocialAvatar(author: _author, size: 96)),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _changePhoto,
              child: const Text('Alterar foto do perfil', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_author.avatarUrl != null)
            Center(
              child: TextButton(
                onPressed: _busy ? null : _removePhoto,
                style: TextButton.styleFrom(foregroundColor: SocialColors.like),
                child: const Text('Remover foto'),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: widget.profile.author.name,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Nome', helperText: 'O nome é definido pela sua academia.'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('edit-profile-bio'),
            controller: _bio,
            maxLength: 150,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Bio', hintText: 'Ex.: Faixa azul · guardeiro · Oss!'),
          ),
        ],
      ),
    ),
  );
}
