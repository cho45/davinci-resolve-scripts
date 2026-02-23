const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('resolveAPI', {
    getSubtitles: () => ipcRenderer.invoke('resolve:getSubtitles'),
    applySubtitles: (srtContent: string) => ipcRenderer.invoke('resolve:applySubtitles', srtContent),
    probeObject: (type: string) => ipcRenderer.invoke('resolve:probeObject', type)
});
