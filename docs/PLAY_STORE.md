# Guia de Empacotamento e Publicação Android (`PLAY_STORE.md`)

Procedimento técnico para geração de pacotes assinados (*APK Release* e *Android App Bundle* — AAB), configuração de permissões de hardware e conformidade com a **Google Play Store** para o aplicativo **Desperrengue** (`v2.8.1+202611082`).

---

## 1. Identificação do Pacote e Versionamento

- **Application ID**: `com.desperrengue.app`
- **Versão Atual (`pubspec.yaml`)**: `2.8.1+202611082`
- **Ícone Adaptativo (`mipmap-anydpi-v26`)**: Monograma geométrico em cobre escovado enquadrado na zona de segurança de 66% (*Safe-Zone*), validado automaticamente por [`ui_polish_test.dart`](../app/test/ui_polish_test.dart).

---

## 2. Permissões Nativas Declaradas e Justificativa de Privacidade

Para atender às políticas de revisão da Google Play Store e ao funcionamento dos módulos de **Biometria Ao Vivo (`ClipOval`)**, **Scanner Documental ISO ID-1** e **Custódia Forense (`SpeculativeEvidencePipeline`)**, o manifesto Android utiliza exclusivamente as permissões estritamente necessárias:

| Permissão Android | Módulo Consumidor | Justificativa Técnica na Google Play Console |
| :--- | :--- | :--- |
| `android.permission.CAMERA` | `_LiveFrontOvalLivenessCameraModal`, `DocumentGuidedScannerModal`, `PerceptualHashGuard` | Captura ao vivo de prova de vida facial na câmera frontal, digitalização guiada de documentos (RG/CNH/CIN) e registro fotográfico forense Antes/Depois sem uso de galeria. |
| `android.permission.ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | `SpeculativeEvidencePipeline`, `ClientSetupScreen` | Geocodificação do imóvel para o Passaporte ABNT NBR 5674 e carimbo geodésico de evidências de garantia. |
| `android.permission.INTERNET` | Cliente Supabase / ViaCEP / Nominatim | Comunicação criptografada TLS 1.3 com o backend transacional. |

---

## 3. Pipeline Automatizado de APK Beta e Compilação AAB

### 3.1. Distribuição Contínua via GitHub Releases (`.github/workflows/beta-release.yml`)
A cada atualização na branch `main`, o workflow [`beta-release.yml`](../.github/workflows/beta-release.yml) compila o binário `app-release.apk` injetando as variáveis de ambiente de produção e publica o artefato na tag `beta-latest` do repositório `WagnerxOliveira/DesperrengueApp_TAI3`.

### 3.2. Geração Manual do Android App Bundle (`.aab`) para a Play Store
```powershell
cd C:\00_Desperrengue\app
flutter build appbundle --release --dart-define-from-file=.env
```
O artefato final é gerado em `app/build/app/outputs/bundle/release/app-release.aab`.
