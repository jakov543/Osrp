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
  getServerAddress: () => ipcRenderer.invoke('server:getAddress'),
  setServerAddress: (a) => ipcRenderer.invoke('server:setAddress', a),
  serverStatus: () => ipcRenderer.invoke('server:status'),
  acceptFiveMLicense: () => ipcRenderer.invoke('fivem:acceptLicense'),
  fivemStatus: () => ipcRenderer.invoke('fivem:status'),
  onFiveMProgress: (cb) => ipcRenderer.on('fivem:progress', (_e, d) => cb(d)),
  login: (u, p) => ipcRenderer.invoke('account:login', u, p),
  register: (u, p) => ipcRenderer.invoke('account:register', u, p),
  logout: () => ipcRenderer.invoke('account:logout'),
  guest: (name) => ipcRenderer.invoke('account:guest', name),
  checkAccount: () => ipcRenderer.invoke('account:check'),
  openLink: (url) => ipcRenderer.invoke('link:open', url),
  minimize: () => ipcRenderer.send('win:minimize'),
  close: () => ipcRenderer.send('win:close')
});
