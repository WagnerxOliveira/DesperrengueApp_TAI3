# Guia Normativo de Provisionamento em Ambiente GNU/Linux — Desperrengue (`v2.8.1`)

> **Classificação Epistemológica:** Procedimento Técnico de Configuração de *Toolchain* em Distribuições GNU/Linux (Ubuntu 22.04/24.04 LTS, Debian 12, Fedora 40+)  
> **Documento Pai:** [`docs/SETUP.md`](../SETUP.md)

---

## 1. Instalação de Dependências de Sistema e Bibliotecas Nativas

Em distribuições baseadas em Debian/Ubuntu, a compilação do motor gráfico do Flutter, do Android SDK e dos utilitários de linha de comando requer os seguintes pacotes de sistema:

```bash
sudo apt-get update && sudo apt-get install -y \
  curl git unzip xz-utils zip libglu1-mesa \
  clang cmake ninja-build pkg-config libgtk-3-dev \
  openjdk-17-jdk nodejs npm
```

---

## 2. Configuração de Variáveis de Ambiente (`~/.bashrc` ou `~/.zshrc`)

Adicionam-se as variáveis de exportação ao arquivo de perfil do *shell* para disponibilizar o Flutter SDK, o JDK 17 e os utilitários `adb` do Android SDK:

```bash
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$HOME/development/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
```

---

## 3. Regras `udev` para Depuração em Hardware Físico Android

Para permitir que o daemon `adb` comunique-se diretamente com smartphones Android via USB sem privilégios de superusuário (`root`), configura-se o grupo `plugdev`:

```bash
sudo usermod -aG plugdev $USER
adb kill-server && adb start-server
adb devices
```

---

## 4. Execução da Bateria de Verificação e Compilação

```bash
# 1. Instalar dependências e validar código estático
cd app
flutter pub get
flutter analyze

# 2. Executar as 26 suítes de testes automatizados (529 testes)
flutter test

# 3. Validar gerador de dossiê PDF (17 testes) e integridade de links Markdown
cd ..
node scripts/test-dossie.mjs
node scripts/check-md-links.mjs
```
