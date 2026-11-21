const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('launcher', {
  info: () => ipcRenderer.invoke('app:info'),
  bootResult: () => ipcRenderer.invoke('boot:result'),
  onSplashStep: (cb) => ipcRenderer.on('splash:step', (_e, data) => cb(data)),
  getSettings: () => ipcRenderer.invoke('settings:get'),
  confirmOwnership: () => ipcRenderer.invoke('ownership:confirm'),
  detectGame: () => ipcRenderer.invoke('game:detect'),
  browseGame: () => ipcRenderer.invoke('game:browse'),
  setPlatform: (p) => ipcRenderer.invoke('game:setPlatform', p),
  reset: () => ipcRenderer.invoke('game:reset'),
  play: (mode) => ipcRenderer.invoke('game:play', mode),
  serverStatus: () => ipcRenderer.invoke('server:status'),
  openLink: (url) => ipcRenderer.invoke('link:open', url),
  minimize: () => ipcRenderer.send('win:minimize'),
  close: () => ipcRenderer.send('win:close')
});
