let toastCallback = null

export function showToast(message, type = 'success') {
  if (toastCallback) {
    toastCallback(message, type)
  }
}

export function registerToast(callback) {
  toastCallback = callback
}

export function unregisterToast() {
  toastCallback = null
}
