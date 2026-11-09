# Política de Segurança, Blindagem Antifraude e Custódia Forense (`SECURITY.md`)

Este documento especifica a arquitetura de defesa em profundidade, o controle de acesso relacional (*Row Level Security*), a mitigação determinística dos **6 Vetores de Fraude (`RN-AF-01` a `RN-AF-14`)** e as garantias de conformidade com a **LGPD (Lei Federal nº 13.709/2018)** implementadas no ecossistema **Desperrengue** (`v2.8.1`).

---

## 1. Superfície de Autenticação e Autorização Relacional (RLS)

1. **Autenticação OAuth2 / PKCE**: Toda sessão de usuário é autenticada via Supabase Auth (GoTrue) utilizando fluxo PKCE e tokens JWT assinados criptograficamente.
2. **Isolamento por *Row Level Security* (RLS)**: Todas as tabelas do esquema `public` operam com `ENABLE ROW LEVEL SECURITY`. Nenhuma tabela sensível (`warranty_pool_ledger`, `escrow_maturation_entries`, `job_mediations`, `forensic_certificates`) aceita comandos `UPDATE` ou `DELETE` diretos provenientes do cliente autenticado.
3. **Mutação Exclusiva via RPCs `SECURITY DEFINER`**: Operações contábeis, transições da máquina de estados de mediação e submissões de KYC biométrico são executadas exclusivamente por funções PL/pgSQL declaradas com `SECURITY DEFINER` e `SET search_path = public`, prevenindo ataques de *search_path hijacking* e escalação horizontal de privilégios.

---

## 2. Mitigação Determinística dos 6 Vetores de Fraude (`RN-AF-01` a `RN-AF-14`)

| Vetor de Ameaça | Regras | Controles Criptográficos e Algorítmicos Ativos |
| :--- | :--- | :--- |
| **1. Conluio Cliente-Profissional (*Cash-Out*)** | `RN-AF-01..04` | Proibição de reembolso em espécie ao cliente; cobertura da Camada 3 restrita ao pagamento direto de **Profissional Socorrista** independente; detecção de ciclos em grafo bipartido (`client_id`, `professional_id`, `device_fingerprint`, `ip_prefix_24`, `pix_holder_cpf_hash`); suspensão imediata por dívida técnica (`suspended_debt`). |
| **2. Sabotagem Pós-Serviço pelo Cliente** | `RN-AF-05..07` | Exigência de **Checklist Fotográfico Antes e Depois** com certificado `forensic_certificates`; validação de **Lacre de Garantia Virtual**; obrigatoriedade de **PIN Presencial de 4 dígitos** gerado no aparelho do cliente para encerrar visita de garantia. |
| **3. Reciclagem de Evidências Fotográficas** | `RN-AF-08..10` | Captura exclusiva via sensor físico (`ImageSource.camera`); bloqueio de metadados EXIF de editores/mensageiros (`WhatsApp`, `Telegram`, `Photoshop`, `Canva`, `GIMP`) e `DateTimeOriginal > 15 min`; **Distância de Hamming (`dHash` 64-bit) $\le 5$ bits** em $O(1)$ via `compute_hamming_distance_64`. |
| **4. *Bypass* por Inflação de Material** | `RN-AF-11..12` | Trava relacional e de domínio $M \le 0.60 \cdot (L + M)$; exigência de comprovante fiscal (`materials_receipt_url`); cobertura de garantia restrita estritamente ao valor de mão de obra ($L$). |
| **5. Golpe do "Falso Socorrista"** | `RN-AF-13` | Elegibilidade restrita a prestadores **Nível Ouro** ($RTS \ge 85$, $\ge 15$ serviços concluídos com $0\%$ de disputa e distância geodésica/grafo disjunta). |
| **6. Ataque Sybil e Laranjas** | `RN-AF-14` | Índices únicos B-Tree sobre `cpf_hash` (SHA-256 + *salt*) e `face_liveness_hash` em `public.profiles`; trava **PIX Same-Holder Lock** (`pix_holder_cpf_hash = cpf_hash`). |

---

## 3. Segurança Biométrica e Antispoofing de Visão Computacional

Implementado em [`document_ocr_and_liveness_service.dart`](../app/lib/core/services/document_ocr_and_liveness_service.dart) e [`client_setup_screen.dart`](../app/lib/features/client/presentation/client_setup_screen.dart):

- **Prova de Vida Ao Vivo (`_LiveFrontOvalLivenessCameraModal`)**: Bloqueia ataques de apresentação (*Presentation Attacks* com fotos impressas ou telas de monitores/notebooks) combinando segmentação de pele humana no espaço $YCbCr$ ($77 \le Cb \le 127$, $133 \le Cr \le 173$), filtro de radiância azul de telas (`blueMonitorRatio < 0.25`), variância Laplaciana ($\sigma_{\text{Lap}}^2 \ge 95.0$) e 3 desafios biomecânicos sequenciais na câmera frontal.
- **Autenticidade Documental ISO ID-1**: Aplica recorte central de 12% (*Core ROI Inset*) e exige divergência estrutural entre Frente e Verso ($\text{Hamming} \ge 10\text{ bits}$, $\text{MAD}_{64\times 64} \ge 0.055$ e $\Delta\sigma_{\text{quadrantes}}^2 \ge 0.040$), além de Face Match multi-ângulo ($0^\circ, 90^\circ, 180^\circ, 270^\circ$) em espaço 128-D não-negativo com similaridade $\ge 78.0\%$.

---

## 4. Proteção de Dados Pessoais e Conformidade LGPD

1. **Minimização e Pseudonimização de CPF**: O número bruto do CPF é validado em memória pelo algoritmo Módulo 11 e convertido em hash criptográfico unidirecional (`cpf_hash`) acompanhado apenas da máscara visual `***.XXX.XXX-**` (`cpf_masked`).
2. **Isolamento de Objetos Sensíveis**: Fotografias de documentos e selfies de verificação são armazenadas nos buckets privados `pro-verifications` e `forensic-evidence` (`public = false`), acessíveis somente via URLs assinadas de curta duração (`createSignedUrl`).
3. **Direito de Eliminação Escopada (`Art. 18, VI da LGPD`)**: A função `public.delete_own_account_scoped(p_scope)` permite que o titular revogue seletivamente seu perfil `client` ou `professional`, anonimizando dados pessoais e preservando apenas os registros contábeis imutáveis exigidos por lei.

---

## 5. Reporte de Vulnerabilidades

Vulnerabilidades de segurança identificadas devem ser reportadas de forma privada através da aba **Security Advisories** do repositório GitHub oficial, incluindo passos determinísticos de reprodução e evidências técnicas.
