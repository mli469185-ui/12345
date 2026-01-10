App({
  globalData: {
    favorites: []
  },
  onLaunch() {
    const stored = wx.getStorageSync('favorites') || [];
    this.globalData.favorites = stored;
  }
});