const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('resolveAPI', {
    getSubtitles: () => ipcRenderer.invoke('resolve:getSubtitles'),
    applySubtitles: (srtContent) => ipcRenderer.invoke('resolve:applySubtitles', srtContent),
    probeObject: (type) => ipcRenderer.invoke('resolve:probeObject', type)
});
