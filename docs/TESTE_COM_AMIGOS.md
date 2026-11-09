# Roteiro de Homologação em Dispositivos Reais (`TESTE_COM_AMIGOS.md`)

Protocolo estruturado para validação empírica de ponta a ponta em smartphones Android e iOS (PWA) das funcionalidades críticas da versão `v2.8.1+202611082`.

---

## 1. Instalação e Atualização da Versão `v2.8.1`

1. **Android (APK Nativo)**:
   - Acesse a página de *Releases* do repositório `WagnerxOliveira/DesperrengueApp_TAI3` (`tag: beta-latest`) ou aguarde o banner automático do `UpdateGate` dentro do aplicativo para baixar e instalar o `desperrengue-beta.apk`.
2. **iOS / Desktop (Web PWA)**:
   - Acesse `https://wagnerxoliveira.github.io/DesperrengueApp_TAI3/` via Safari (iOS) ou Chrome e utilize a opção *"Adicionar à Tela de Início"*.

---

## 2. Roteiro de Verificação Funcional (4 Cenários Críticos)

### Cenário 1 — Onboarding do Cliente com Biometria Ao Vivo, Scanner ISO ID-1 e OCR
1. Crie uma conta nova ou acesse o fluxo de configuração inicial (`ClientSetupScreen`).
2. **Etapa 1 e Etapa 2**: Preencha Nome Completo, Telefone (obrigatório), CPF válido (Módulo 11) e CEP residencial.
3. **Etapa 3 (Prova de Vida Ao Vivo)**: Toque em *"Abrir Câmera Frontal (Moldura Oval)"*. Verifique que a câmera frontal abre ao vivo dentro da elipse e execute os **3 desafios biomecânicos** (centralizar rosto, girar levemente a cabeça e piscar). Teste apontar a câmera para um monitor de computador e confirme o bloqueio pelo filtro anti-monitor.
4. **Etapa 4 (Scanner ISO ID-1 + Face Match + OCR)**: Fotografe a **Frente** e o **Verso** do documento dentro da moldura retangular `1.586 : 1`. Verifique o bloqueio caso tente enviar a mesma foto duas vezes e confira o card **Transcrição Automática do Documento (OCR)** com o percentual de *Face Match* ($\ge 78\%$) antes de concluir.

### Cenário 2 — Abertura de Chamado e Proposta com Smart Split Anti-Bypass
1. No Modo Cliente, abra um chamado em uma das **33 categorias** informando descrição e fotos.
2. No Modo Profissional, envie uma proposta discriminando **Mão de Obra** (taxa de $15\%$) e **Peças/Materiais com Nota Fiscal** (taxa de $0\%$, respeitando o limite de $60\%$ do total).

### Cenário 3 — Garantia em 3 Camadas, 4ª Aba "Em Mediação" e PIN de 4 Dígitos
1. Após concluir um serviço com o **Checklist Antes e Depois**, acesse a **Carteira Bipartida** e verifique o saldo retido em maturação ($D+7 / D+5 / D+2$).
2. Na 4ª aba **"Em Mediação"**, abra um chamado de garantia tirando uma foto em tempo real via câmera nativa (verificando o selo `dHash` de 64 bits).
3. Observe o congelamento imediato do saldo em maturação e o cronômetro regressivo de **4 horas (SLA Camada 2)** rodando a $60\text{ FPS}$.
4. Agende o retorno técnico e conclua a visita digitando o **PIN Presencial de 4 Dígitos** exibido no aparelho do cliente.

### Cenário 4 — Passaporte Oficial de Manutenção do Imóvel (ABNT NBR 5674)
1. Acesse **Perfil → Prontuário da Casa (Passaporte)**.
2. Explore a apresentação interativa, o simulador de valorização patrimonial e exporte o documento vetorial `%PDF-1.4` com os certificados criptográficos dos serviços concluídos.
