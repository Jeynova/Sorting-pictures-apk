import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Sorter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PhotoSorter(),
    );
  }
}

class PhotoSorter extends StatefulWidget {
  const PhotoSorter({super.key});

  @override
  State<PhotoSorter> createState() => _PhotoSorterState();
}

class _PhotoSorterState extends State<PhotoSorter> {
  final Logger _logger = Logger();
  List<File> images = [];
  int currentIndex = 0;
  String selectedDestination = '';

  // Demande des permissions
  Future<void> _requestPermissions() async {
    if (!await Permission.storage.isGranted) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        _logger.w("Permissions refusées.");
        openAppSettings(); // Ouvrir les paramètres pour activer les permissions
      }
    }
  }

  // Sélectionner des fichiers images
  Future<void> _pickImages() async {
    await _requestPermissions(); // Demander les permissions

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'], // Filtre pour les images
      allowMultiple: true, // Autoriser la sélection de plusieurs fichiers
    );

    if (result != null) {
      List<File> selectedFiles =
          result.paths.map((path) => File(path!)).toList();

      setState(() {
        images = selectedFiles;
        currentIndex = 0;
      });

      _showAlert(
          context, "Images chargées", "${images.length} images trouvées.");
    } else {
      _showAlert(context, "Aucune sélection", "Aucune image sélectionnée.");
    }
  }

  // Choisir un dossier cible
  Future<void> _pickDestinationFolder() async {
    String? pickedDir = await FilePicker.platform.getDirectoryPath();
    if (pickedDir != null) {
      setState(() {
        selectedDestination = pickedDir;
      });
      _showAlert(context, "Dossier cible sélectionné",
          "Les images seront déplacées vers $pickedDir.");
    }
  }

  // Déplacer une image
  Future<void> _moveImage(File image) async {
    if (selectedDestination.isEmpty) {
      _showAlert(context, "Erreur", "Aucun dossier cible sélectionné.");
      return;
    }

    try {
      final newPath = '$selectedDestination/${image.uri.pathSegments.last}';
      await image.rename(newPath);
      setState(() {
        images.removeAt(currentIndex);
        currentIndex = currentIndex >= images.length ? 0 : currentIndex;
      });
      _showAlert(context, "Image déplacée", "Image déplacée avec succès.");
    } catch (e) {
      _showAlert(context, "Erreur", "Impossible de déplacer l'image : $e");
    }
  }

  // Supprimer une image
  Future<void> _deleteImage(File image) async {
    try {
      await image.delete();
      setState(() {
        images.removeAt(currentIndex);
        currentIndex = currentIndex >= images.length ? 0 : currentIndex;
      });
      _showAlert(context, "Image supprimée", "L'image a été supprimée.");
    } catch (e) {
      _showAlert(context, "Erreur", "Impossible de supprimer l'image : $e");
    }
  }

  // Afficher une alerte
  void _showAlert(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tri de Photos'),
      ),
      body: images.isEmpty
          ? const Center(
              child: Text('Aucune image à afficher.'),
            )
          : Center(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    // Swipe droit : Ignorer l'image
                    setState(() {
                      currentIndex = (currentIndex + 1) %
                          images.length; // Passer à l'image suivante
                    });
                  } else if (details.primaryVelocity! < 0) {
                    // Swipe gauche : Déplacer l'image
                    _moveImage(images[currentIndex]);
                  }
                },
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    // Swipe bas : Supprimer l'image
                    _deleteImage(images[currentIndex]);
                  }
                },
                child: Image.file(
                  images[currentIndex],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          FloatingActionButton.extended(
            onPressed: _pickImages,
            label: const Text("Charger Images"),
            icon: const Icon(Icons.photo_library),
          ),
          FloatingActionButton.extended(
            onPressed: _pickDestinationFolder,
            label: const Text("Dossier Cible"),
            icon: const Icon(Icons.create_new_folder),
          ),
        ],
      ),
    );
  }
}
