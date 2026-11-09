# desperrengue_app — Cliente Multiplataforma Flutter (Android, iOS e Web/PWA)

Aplicativo multiplataforma do ecossistema **Desperrengue**, desenvolvido em **Flutter 3.47 / Dart $\ge$ 3.13.4** sob arquitetura desacoplada em quatro camadas, gerenciamento de estado reativo (Riverpod + `ValueListenable`), processamento paralelo de visão computacional em *Worker Isolates* (`Isolate.run`) e renderização otimizada a $60\text{--}120\text{ FPS}$.

Para a visão arquitetural completa do sistema, consulte o [README principal da raiz](../README.md), a documentação do núcleo relacional em [`../supabase/README.md`](../supabase/README.md), a especificação técnica em [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) e as fichas de interface em [`../docs/specs`](../docs/specs).

---

## 1. Modelo Operacional Multi-Modo e Unificação Biométrica

Uma única conta autenticada (`public.profiles`) pode operar no modo **Cliente** (*"Preciso de um serviço"*) e no modo **Profissional** (*"Quero trabalhar"*), compartilhando de forma transparente a homologação de identidade civil e biométrica:

```text
Autenticação (GoTrue JWT / OTP 6 dígitos / Google OAuth)
  └── Seleção de Modo (RoleSelectionScreen / destinationFor)
        ├── Modo Cliente (Tema Laranja #F26B0F)
        │     └── ClientSetupScreen (4 Etapas):
        │           1. Dados Civis + CPF (Módulo 11 em O(1))
        │           2. Endereço + Geocodificação de Alta Precisão + Pino no Mapa
        │           3. Prova de Vida Facial Ao Vivo no Oval (YCbCr + 3 Desafios)
        │           4. Scanner Guiado ISO ID-1 (Frente/Verso) + Face Match 128-D + OCR
        │                 └── Home do Cliente / Pedidos (4 Abas) / Prontuário ABNT NBR 5674
        └── Modo Profissional (Tema Azul #1B3A78)
              └── Verificação KYC + Reaproveitamento Automático (+30 pts no Score RTS)
                    └── Painel Operacional / Oportunidades / Execução Geofence / Carteira Bipartida
```

---

## 2. Arquitetura Interna de Diretórios (`app/lib/`)

```text
lib/
├── main.dart                                      # Inicialização paralela, ConstrainedBox(480px), UpdateGate, BootGate
├── core/
│   ├── boot/app_initialization_service.dart       # Orquestração assíncrona de boot e sessão segura
│   ├── constants/env.dart                         # Parâmetros de compilação (--dart-define)
│   ├── models/                                    # Entidades imutáveis e modelos matemáticos puros
│   │   ├── user_profile.dart                      # Perfil unificado e função pura destinationFor(...)
│   │   ├── marketplace_models.dart                # Job, Quote, ProviderCard, Payment, Review
│   │   ├── wallet_models.dart                     # Money (centavos bigint), FundsCheck, ClientWallet, PixTopup
│   │   ├── fintech_warranty_models.dart           # SecurityAndLgpdGuard, SmartSplitBreakdown, WarrantyCertificate, PropertyMaintenancePassport
│   │   ├── provider_portfolio_models.dart         # Modelos de vitrine, antes/depois e certificação técnica
│   │   ├── smart_triage_models.dart               # Árvores de decisão de triagem inteligente por categoria
│   │   ├── scheduling_models.dart                 # Estados de agendamento, geofence e dupla trava
│   │   └── geocode_models.dart                    # Precisão espacial (house, street, locality)
│   ├── security/
│   │   └── perceptual_hash_guard.dart             # Guarda de câmera física, dHash 64-bit, ROI Inset (12%) e MAD 64x64
│   ├── services/                                  # Camada exclusiva de comunicação com RPCs, Storage e Isolates
│   │   ├── document_ocr_and_liveness_service.dart # Liveness YCbCr ao vivo, filtro anti-monitor, Laplaciano, Face Match 128-D e OCR
│   │   ├── live_camera_frame_bridge.dart          # Ponte condicional (Android YUV420/NV21, iOS BGRA8888, Web HTML5 video)
│   │   ├── warranty_escrow_service.dart           # SpeculativeEvidencePipeline (GPS warm-up + upload concorrente) e Camadas 1–3
│   │   ├── desperrengue_official_pdf_service.dart # Compilador determinístico %PDF-1.4 em Isolate.run (Garantia e Passaporte ABNT)
│   │   ├── accurate_geo_routing_service.dart      # Cálculos geodésicos, OSRM e trava temporal de privacidade de endereço
│   │   ├── precise_geocoder.dart                  # Cascata ViaCEP -> Photon -> AwesomeAPI -> Nominatim com validação municipal
│   │   ├── app_version_and_update_service.dart    # Controle de versão (v2.8.1+202611082) e limpeza de cache PWA
│   │   ├── profile_service.dart · job_service.dart · provider_service.dart · wallet_service.dart
│   │   └── scheduling_service.dart · smart_triage_service.dart · speech_service.dart · text_refine_service.dart
│   ├── state/                                     # Controladores reativos Riverpod
│   │   ├── anti_bypass_fintech_controller.dart    # Orquestração de Smart Split, custódia, mediação e Passaporte do Imóvel
│   │   ├── provider_portfolio_controller.dart     # Gestão de portfólio, curadoria e casos auditados
│   │   ├── smart_triage_controller.dart           # Estado do diagnóstico guiado
│   │   ├── theme_controller.dart · privacy_mode.dart · wallet_providers.dart
│   ├── storage/                                   # Persistência local criptografada (Keystore/Keychain e SharedPreferences)
│   ├── ui/                                        # Design System Material 3, tokens semânticos e componentes reutilizáveis
│   └── utils/                                     # Formatadores monetários, temporais, geodésicos e normalizador de tags
└── features/
    ├── auth/presentation/                         # Login, OTP, RoleSelectionScreen, KYC Etapas 1–7, AuthGate, PostAuthRouter
    ├── boot/                                      # AnimatedSplashScreen ("casinha"), BootGate e UpdateGate
    ├── client/presentation/                       # ClientSetupScreen (KYC 4 etapas), Home, Busca, Wizard, ClientOrdersTab (4 abas), Carteira
    ├── provider/presentation/                     # Painel, Oportunidades, Execução Geofence, Evidências, PIN, WalletTab Bipartida, Dossiê
    └── shared/presentation/                       # FintechWarrantyWidgets (Mediação 5 fases, Comparador Forense, Passaporte ABNT), Chat, Mapas
```

---

## 3. Destaques de Engenharia no Cliente Flutter

1. **Câmera Frontal Ao Vivo no Oval e Liveness Biomecânico (`ClientSetupScreen` — Etapa 3):**
   - Renderiza o `CameraPreview` frontal diretamente dentro do `ClipOval` com amostragem a cada `140 ms`, segmentando crominância epidérmica em espaço $YCbCr$, bloqueando telas/monitores (`blueMonitorRatio < 0.25`) e validando os 3 desafios físicos sem uso de `Future.delayed`.
2. **Scanner Documental Guiado ISO/IEC 7810 ID-1 e Card Visível de OCR (`ClientSetupScreen` — Etapa 4):**
   - `DocumentGuidedScannerModal` e `DocumentScannerOverlayPainter` projetam a máscara oficial com alternância entre **Horizontal (Deitada)** e **Vertical (Em pé)**, guias internas para **Foto 3×4** e **QR Code / MRZ**, recorte estrito da ROI (`cropDocumentToGuidedFrameNamed`), distinção Frente/Verso por `dHash` + $\text{MAD}_{64\times 64}$, *Face Match* multi-ângulo ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) com similaridade em $[0\%, 100\%]$ e exibição imediata do card `_OcrTranscribedSummaryCard`.
3. **4ª Aba *"Em Mediação"*, Carteira Bipartida e Comparador Forense:**
   - `MediationAndWarrantyTabView` exibe a máquina de estados de 5 fases com cronômetro isolado por `RepaintBoundary` (`ValueListenableBuilder<Duration>`), comparador lado a lado em 3 colunas (`ForensicSplitViewComparator`) e acionamento da Camada 3.
   - `BipartiteProviderWalletCard` segrega o **Saldo Livre para Saque PIX Imediato** do **Saldo em Maturação de Garantia ($D+7 / D+5 / D+2$)**.
4. **Trava Temporal e de Perfil na Geolocalização:**
   - Na visão do **Cliente**, o endereço é informativo (sem abertura acidental de rota). Na visão do **Profissional**, antes da data agendada do serviço, exibe-se apenas o **Raio em km e o Nome da Cidade**, liberando o logradouro exato e a rota OSRM exclusivamente no dia agendado.

---

## 4. Comandos de Verificação, Testes e Compilação

```bash
flutter pub get
flutter analyze     # Critério estrito: "No issues found!" (0 erros, 0 avisos)
flutter test        # Executa os 529 testes automatizados (unitários, widgets, visão computacional e Red Team)
flutter run         # Execução em dispositivo físico ou emulador
```

Compilação para produção Web/PWA:

```bash
flutter build web --release --base-href "/DesperrengueApp_TAI3/" --no-wasm-dry-run
```
