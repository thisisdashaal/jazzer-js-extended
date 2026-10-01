#!/bin/bash
set -e

# Цвета для вывода сообщений
ORANGE='\033[38;5;208m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${ORANGE}[*] Starting Jazzer.js Coverage Setup & Build...${NC}"

# Определяем корневую директорию проекта (на уровень выше папки scripts)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAZZER_DIR="$ROOT_DIR/jazzer.js"
PATCHES_DIR="$ROOT_DIR/patches"
PREBUILT_DIR="$ROOT_DIR/prebuilt-llvm"

if [ ! -d "$JAZZER_DIR" ]; then
    echo -e "${RED}[!] Error: 'jazzer.js' directory not found at $JAZZER_DIR${NC}"
    exit 1
fi

if [ ! -d "$PATCHES_DIR" ]; then
    echo -e "${RED}[!] Error: 'patches' directory not found at $PATCHES_DIR${NC}"
    exit 1
fi

# Подготавливаем все директории пребилда
echo -e "${ORANGE}[+] Preparing the repository structure...${NC}"
tar -xvf "$PREBUILT_DIR/bin/prebuilt-llvm-bin-clang++.tar.xz" -C "$PREBUILT_DIR/bin"
tar -xvf "$PREBUILT_DIR/bin/prebuilt-llvm-bin-clang.tar.xz" -C "$PREBUILT_DIR/bin"
tar -xvf "$PREBUILT_DIR/bin/prebuilt-llvm-bin-clang-20.tar.xz" -C "$PREBUILT_DIR/bin"

# --- Шаг 1: Применение патчей через утилиту patch ---
echo -e "${ORANGE}[+] Applying relevant patches to jazzer.js using 'patch'...${NC}"
cd "$JAZZER_DIR"

for patch_file in "$PATCHES_DIR"/*.patch; do
    if [ -f "$patch_file" ]; then
        filename=$(basename "$patch_file")

        # Пропускаем любые патчи для LLVM (начинающиеся с llvm)
        if [[ "$filename" == llvm* ]]; then
            echo -e "${ORANGE}Skipping LLVM-specific patch: $filename${NC}"
            continue
        fi

        # Проверяем, применится ли патч (dry-run)
        if patch -p2 --dry-run --silent < "$patch_file" 2>/dev/null; then
            echo -e "${ORANGE}Applying patch: $filename${NC}"
            patch -p2 < "$patch_file"
        else
            echo -e "${ORANGE}Patch already applied or cannot be applied cleanly: $filename${NC}"
        fi
    fi
done

# --- Шаг 2: Автоматическая сборка самого jazzer.js (JS/TS части) ---
echo -e "${ORANGE}[+] Installing dependencies and building jazzer.js (TypeScript)...${NC}"
npm install
npm run build

# --- Шаг 3: Сборка нативного аддона с LLVM-профилированием через cmake-js ---
echo -e "${ORANGE}[+] Building native fuzzer addon with cmake-js...${NC}"
cd packages/fuzzer

# Очищаем старые артефакты сборки
npx cmake-js clean
rm -rf build prebuilds/fuzzer-linux-x64.node

# Экспортируем переменные компиляторов для cmake-js / node-gyp
export CC="$ROOT_DIR/prebuilt-llvm/bin/clang"
export CXX="$ROOT_DIR/prebuilt-llvm/bin/clang++"

# Запускаем компиляцию через cmake-js (чтобы корректно подтянулись Node.js заголовки)
#npx cmake-js build --config Release
npm run build -- --rebuild

echo -e "${GREEN}[SUCCESS] Setup, compilation, and build completed successfully!${NC}"
echo -e "${ORANGE}You can now run your fuzzer with last-cov-time:${NC}"
echo -e "node jazzer.js/packages/core/dist/cli.js /path/to/fuzz.js --sync -- -exit_on_time=15 -print_final_stats=1"
echo -e "${ORANGE}To perform a quick test run, execute the command below:${NC}"
echo -e "node jazzer.js/packages/core/dist/cli.js jazzer.js/examples/FuzzedDataProvider/fuzz.js --sync -- -exit_on_time=15 -print_final_stats=1"
