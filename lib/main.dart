import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
  List<File> images = [];
  int currentIndex = 0;
  String sourceDirectory = '';
  String selectedDestination = '';

  // Ajout de la fonction _requestPermissions
  Future<void> _requestPermissions() async {
    if (await Permission.storage.isGranted) {
      print("Permission accordée.");
    } else if (await Permission.manageExternalStorage.isGranted) {
      print("Permission accordée pour MANAGE_EXTERNAL_STORAGE.");
    } else {
      var status = await Permission.storage.request();
      if (status.isGranted) {
        print("Permission accordée.");
      } else if (status.isPermanentlyDenied) {
        print("Permission refusée de façon permanente.");
        openAppSettings(); // Ouvre les paramètres pour activer manuellement les permissions
      } else {
        print("Permission refusée.");
      }
    }
  }

  // Fonction pour choisir un dossier source et charger les images
  Future<void> _pickSourceFolder() async {
    await _requestPermissions(); // Demander les permissions avant de continuer

    String? pickedDir = await FilePicker.platform.getDirectoryPath();
    if (pickedDir != null) {
      final dir = Directory(pickedDir);

      // Liste et filtre les fichiers image
      final files = dir.listSync().whereType<File>().where((file) {
        final ext = file.path
            .split('.')
            .last
            .toLowerCase(); // Extensions insensibles à la casse
        return ['jpg', 'jpeg', 'png'].contains(ext);
      }).toList();

      // Logs pour déboguer les fichiers détectés
      print("Chemin du dossier source : $pickedDir");
      print("Tous les fichiers dans le dossier :");
      dir.listSync().forEach((entity) {
        print(entity.path);
      });

      if (files.isNotEmpty) {
        setState(() {
          sourceDirectory = pickedDir;
          images = files;
          currentIndex = 0;
        });
        _showAlert(
            context, "Dossier chargé", "${files.length} images trouvées.");
      } else {
        _showAlert(
            context, "Aucune image", "Aucune image trouvée dans ce dossier.");
      }
    }
  }

  // Fonction pour choisir ou créer un dossier cible
  Future<void> _pickDestinationFolder() async {
    String? pickedDir = await FilePicker.platform.getDirectoryPath();
    if (pickedDir != null) {
      setState(() {
        selectedDestination = pickedDir;
      });
      _showAlert(context, "Dossier cible sélectionné",
          "Images seront déplacées vers $pickedDir.");
    }
  }

  // Déplace une image vers le dossier cible
  Future<void> _moveImage(File image) async {
    if (selectedDestination.isEmpty) {
      _showAlert(context, "Erreur", "Aucun dossier cible sélectionné.");
      return;
    }

    try {
      final targetDir = Directory(selectedDestination);
      if (!await targetDir.exists()) {
        await targetDir.create();
      }

      final newPath = '${targetDir.path}/${image.uri.pathSegments.last}';
      await image.rename(newPath);
      setState(() {
        images.removeAt(currentIndex);
        if (currentIndex >= images.length) {
          currentIndex = images.isEmpty ? 0 : images.length - 1;
        }
      });
      _showAlert(context, "Image déplacée",
          "Image déplacée vers $selectedDestination.");
    } catch (e) {
      _showAlert(context, "Erreur", "Impossible de déplacer l'image : $e");
    }
  }

  // Supprime une image
  Future<void> _deleteImage(File image) async {
    try {
      await image.delete();
      setState(() {
        images.removeAt(currentIndex);
        if (currentIndex >= images.length) {
          currentIndex = images.isEmpty ? 0 : images.length - 1;
        }
      });
      _showAlert(
          context, "Image supprimée", "L'image a été supprimée avec succès.");
    } catch (e) {
      _showAlert(context, "Erreur", "Impossible de supprimer l'image : $e");
    }
  }

  // Affiche une alerte contextuelle
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
                      currentIndex = (currentIndex + 1) % images.length;
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
                child: Image.file(images[currentIndex]),
              ),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          FloatingActionButton.extended(
            onPressed: _pickSourceFolder,
            label: const Text("Source"),
            icon: const Icon(Icons.folder),
          ),
          FloatingActionButton.extended(
            onPressed: _pickDestinationFolder,
            label: const Text("Cible"),
            icon: const Icon(Icons.create_new_folder),
          ),
        ],
      ),
    );
  }
}
