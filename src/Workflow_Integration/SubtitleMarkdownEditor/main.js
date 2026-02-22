const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const os = require('os');
const fs = require('fs');

// Load the integration bridge
let WorkflowIntegration;
try {
    WorkflowIntegration = require('./WorkflowIntegration.node');
} catch (e) {
    console.error("Failed to load WorkflowIntegration.node:", e);
}

const PLUGIN_ID = 'com.mycompany.subtitleeditor';
let mainWindow;
let resolveObj = null;

async function initResolve() {
    if (!resolveObj && WorkflowIntegration) {
        try {
            const isSuccess = await WorkflowIntegration.Initialize(PLUGIN_ID);
            if (isSuccess) {
                resolveObj = await WorkflowIntegration.GetResolve();
            }
        } catch (e) {
            console.error("Initialization error:", e);
        }
    }
    return resolveObj;
}

async function getTimeline() {
    const resolve = await initResolve();
    if (!resolve) return null;
    const projectManager = await resolve.GetProjectManager();
    const project = await projectManager.GetCurrentProject();
    if (!project) return null;
    return await project.GetCurrentTimeline();
}

async function getMediaPool() {
    const resolve = await initResolve();
    if (!resolve) return null;
    const projectManager = await resolve.GetProjectManager();
    const project = await projectManager.GetCurrentProject();
    if (!project) return null;
    return await project.GetMediaPool();
}

ipcMain.handle('resolve:getSubtitles', async () => {
    try {
        const timeline = await getTimeline();
        if (!timeline) throw new Error("No active timeline found.");

        const items = await timeline.GetItemListInTrack('subtitle', 1);
        const subtitles = [];
        if (items) {
            for (const item of items) {
                subtitles.push({
                    name: await item.GetName(),
                    start: await item.GetStart(),
                    end: await item.GetEnd()
                });
            }
        }

        const resolve = await initResolve();
        const projectManager = await resolve.GetProjectManager();
        const project = await projectManager.GetCurrentProject();
        let frameRate = await project.GetSetting('timelineFrameRate');
        const timelineStartFrame = await timeline.GetStartFrame();

        if (typeof frameRate === 'object' || !frameRate) {
            frameRate = 24.0;
        }

        return {
            frameRate: frameRate.toString(),
            timelineStartFrame,
            subtitles
        };
    } catch (e) {
        return { error: e.toString() };
    }
});

ipcMain.handle('resolve:applySubtitles', async (event, srtContent) => {
    try {
        const tempSrt = path.join(os.tmpdir(), `sub_${Date.now()}.srt`);
        fs.writeFileSync(tempSrt, srtContent, 'utf8');

        const mediaPool = await getMediaPool();
        const timeline = await getTimeline();
        if (!mediaPool || !timeline) throw new Error("No timeline or media pool available.");

        // 1. Delete existing clips on Subtitle Track 1
        const items = await timeline.GetItemListInTrack('subtitle', 1);
        if (items && items.length > 0) {
            await timeline.DeleteClips(items);
        }

        // 2. Import the new SRT clip
        const importedClips = await mediaPool.ImportMedia([tempSrt]);
        if (!importedClips || importedClips.length === 0) {
            throw new Error("Failed to import SRT to Media Pool.");
        }

        // 3. Append to timeline (Should land at timeline start on an empty track)
        const success = await mediaPool.AppendToTimeline([importedClips[0]]);

        // Cleanup
        setTimeout(() => {
            try { fs.unlinkSync(tempSrt); } catch (e) { }
        }, 5000);

        return { success: !!success };
    } catch (e) {
        return { error: e.toString() };
    }
});

// Debug probe handler
ipcMain.handle('resolve:probeObject', async (event, type) => {
    try {
        const timeline = await getTimeline();
        let target = null;
        if (type === 'timeline') target = timeline;
        if (type === 'timelineItem') {
            const items = await timeline.GetItemListInTrack('video', 1);
            if (items && items.length > 0) target = items[0];
        }
        if (type === 'mediaPool') target = await getMediaPool();

        if (!target) return { error: "Target object not found for probing." };

        const methods = [];
        const properties = [];
        for (let prop in target) {
            try {
                if (typeof target[prop] === 'function') {
                    methods.push(prop);
                } else {
                    properties.push(prop);
                }
            } catch (inner) { }
        }
        return { methods, properties };
    } catch (e) {
        return { error: e.toString() };
    }
});

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 850,
        height: 650,
        backgroundColor: '#1a1a1a',
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true,
            sandbox: false
        }
    });

    mainWindow.loadFile('index.html');
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
    if (WorkflowIntegration && WorkflowIntegration.CleanUp) {
        WorkflowIntegration.CleanUp();
    }
    if (process.platform !== 'darwin') {
        app.quit();
    }
});
