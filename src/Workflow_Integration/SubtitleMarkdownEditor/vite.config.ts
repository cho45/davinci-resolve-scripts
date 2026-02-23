import { defineConfig } from 'vite';
import { resolve } from 'path';
import { copyFileSync, existsSync, mkdirSync } from 'fs';
import { execSync } from 'child_process';

// プラグイン名を変えるだけで他のプロジェクトにも流用可能
const PLUGIN_NAME = 'SubtitleMarkdownEditor';
const RESOLVE_PLUGIN_DIR = `C:/ProgramData/Blackmagic Design/DaVinci Resolve/Support/Workflow Integration Plugins/${PLUGIN_NAME}`;

let buildHash = 'unknown';
try {
    buildHash = execSync('git rev-parse --short HEAD').toString().trim();
} catch (e) {
    buildHash = Date.now().toString(36);
}

// Helper plugin to copy WorkflowIntegration.node and manifest.xml
function copyAssetsPlugin() {
    return {
        name: 'copy-assets',
        closeBundle() {
            const outDir = RESOLVE_PLUGIN_DIR;
            if (!existsSync(outDir)) {
                mkdirSync(outDir, { recursive: true });
            }

            // Copy the native node extension
            try {
                copyFileSync(
                    resolve(__dirname, 'WorkflowIntegration.node'),
                    resolve(outDir, 'WorkflowIntegration.node')
                );
            } catch (e) {
                console.warn('Warning: Could not copy WorkflowIntegration.node. It may be missing.');
            }

            // Copy manifest
            try {
                copyFileSync(
                    resolve(__dirname, 'manifest.xml'),
                    resolve(outDir, 'manifest.xml')
                );
            } catch (e) {
                console.warn('Warning: Could not copy manifest.xml.');
            }
            console.log('\n✅ Build complete and assets copied to DaVinci Resolve directory.');
        }
    };
}

export default defineConfig({
    base: './', // Use relative paths for built assets
    define: {
        __BUILD_HASH__: JSON.stringify(buildHash)
    },
    build: {
        outDir: RESOLVE_PLUGIN_DIR,
        emptyOutDir: false, // Do not clean the directory because Resolve locks WorkflowIntegration.node
        target: 'esnext',
        rollupOptions: {
            input: {
                main: resolve(__dirname, 'index.html'),
                electronMain: resolve(__dirname, 'src/main.ts'),
                preload: resolve(__dirname, 'src/preload.ts')
            },
            output: {
                entryFileNames: (assetInfo) => {
                    if (assetInfo.name === 'electronMain') return 'main.js';
                    if (assetInfo.name === 'preload') return 'preload.js';
                    return 'assets/[name]-[hash].js';
                },
                format: 'cjs' // Resolve's Electron expects CommonJS for main/preload
            },
            external: ['electron', 'path', 'os', 'fs', 'child_process', './WorkflowIntegration.node']
        }
    },
    plugins: [copyAssetsPlugin()]
});
