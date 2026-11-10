import 'package:flutter/material.dart';

import '../models/marketplace_models.dart';
import '../services/media_service.dart';
import 'app_theme.dart';
import './app_tokens.dart';
import 'category_brand_emblem.dart';
export 'category_brand_emblem.dart';

IconData categoryIcon(String name) {
  switch (name) {
    case 'Elétrica':
      return Icons.bolt_rounded;
    case 'Encanador':
      return Icons.plumbing_rounded;
    case 'Limpeza':
      return Icons.cleaning_services_rounded;
    case 'Montagem':
      return Icons.chair_alt_rounded;
    case 'Pintura':
      return Icons.format_paint_rounded;
    case 'Chaveiro':
      return Icons.vpn_key_rounded;
    case 'Pedreiro':
      return Icons.construction_rounded;
    case 'Gesso':
      return Icons.light_rounded;
    case 'Marcenaria':
      return Icons.carpenter_rounded;
    case 'Ar-condicionado':
      return Icons.air_rounded;
    case 'Pequenos Reparos':
      return Icons.home_repair_service_rounded;
    case 'Jardinagem':
      return Icons.yard_rounded;
    case 'Dedetização':
      return Icons.pest_control_rounded;
    case 'Vidraceiro':
      return Icons.sensor_window_rounded;
    case 'Serralheria':
      return Icons.fence_rounded;
    case 'Telhados e Calhas':
      return Icons.roofing_rounded;
    case 'Impermeabilização':
      return Icons.shield_rounded;
    case 'Desentupidora':
      return Icons.water_drop_rounded;
    case 'Piscina':
      return Icons.pool_rounded;
    case 'Eletrodomésticos':
      return Icons.local_laundry_service_rounded;
    case 'TV e Antenas':
      return Icons.connected_tv_rounded;
    case 'Câmeras e Alarmes':
      return Icons.security_rounded;
    case 'Portões e Interfones':
      return Icons.settings_remote_rounded;
    case 'Energia Solar':
      return Icons.solar_power_rounded;
    case 'Gás e Aquecedores':
      return Icons.local_fire_department_rounded;
    case 'Pisos e Revestimentos':
      return Icons.layers_rounded;
    case 'Cortinas e Persianas':
      return Icons.curtains_rounded;
    case 'Estofados e Tapetes':
      return Icons.weekend_rounded;
    case 'Mudanças e Fretes':
      return Icons.local_shipping_rounded;
    case 'Informática e Redes':
      return Icons.wifi_tethering_rounded;
    case 'Cuidador de Idosos':
      return Icons.elderly_rounded;
    case 'Babá':
      return Icons.child_care_rounded;
    case 'Pet Care':
      return Icons.pets_rounded;
    default:
      return Icons.handyman_rounded;
  }
}

Color categoryColor(String name) {
  final spec = resolveCategoryBrandSpec(name);
  for (final c in kCategories) {
    if (c.name == name) return spec.primaryColor.withValues(alpha: 0.20);
  }
  return AppColors.surface;
}

/// Imagem de bucket PRIVADO (URL assinada, com cache).
class SignedImage extends StatelessWidget {
  const SignedImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<String?>(
          future: MediaService().signedUrl(path),
          builder: (context, snap) {
            final url = snap.data;
            if (url == null) {
              return Container(
                color: context.tk.surface,
                child: Center(
                  child: snap.connectionState == ConnectionState.done
                      ? Icon(Icons.broken_image_outlined, color: context.tk.textMuted)
                      : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            return Image.network(url, fit: fit, width: width, height: height,
                errorBuilder: (_, _, _) => Container(
                      color: context.tk.surface,
                      child: Icon(Icons.broken_image_outlined, color: context.tk.textMuted),
                    ));
          },
        ),
      ),
    );
  }
}

/// Imagem de bucket PÚBLICO (portfólio/avatar) a partir do caminho salvo.
class PublicImage extends StatelessWidget {
  const PublicImage({super.key, required this.path, this.width, this.height, this.fit = BoxFit.cover, this.radius = 12});

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = path.startsWith('http') ? path : MediaService().publicUrl(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: context.tk.surface,
          child: Icon(Icons.broken_image_outlined, color: context.tk.textMuted),
        ),
      ),
    );
  }
}
