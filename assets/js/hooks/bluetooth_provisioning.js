/**
 * LiveView hook for Bluetooth provisioning of badge scanners.
 * Uses the esp-ble-prov library to communicate with ESP32 devices.
 */
import ESPProvisioner, { Security0 } from 'esp-ble-prov'

// ESP32 Badge Reader BLE configuration
const SERVICE_UUID = 'a3c87500-8ed3-4bdf-8a39-a01bebede295'
const DEVICE_PREFIX = 'LAN_BADGE_READER_'

const BluetoothProvisioning = {
  mounted() {
    this.provisioner = null
    this.deviceName = null

    // Check browser support - WebBluetooth requires secure context (HTTPS)
    if (!window.isSecureContext) {
      this.pushEvent("bluetooth_unsupported", { reason: "requires_https" })
    } else if (!navigator.bluetooth) {
      this.pushEvent("bluetooth_unsupported", { reason: "not_available" })
    }

    // Handle connect request from LiveView
    this.handleEvent("ble_connect", async () => {
      await this.connect()
    })

    // Handle disconnect request from LiveView
    this.handleEvent("ble_disconnect", async () => {
      await this.disconnect()
    })

    // Handle provisioning request from LiveView
    this.handleEvent("ble_provision", async (config) => {
      await this.provision(config)
    })
  },

  destroyed() {
    if (this.provisioner) {
      try {
        this.provisioner.disconnect()
      } catch (e) {
        // Ignore disconnect errors on destroy
      }
    }
  },

  async connect() {
    try {
      this.pushEvent("ble_status", { status: "connecting", message: "Searching for devices..." })

      this.provisioner = new ESPProvisioner({
        deviceNamePrefix: DEVICE_PREFIX,
        serviceUUID: SERVICE_UUID,
        security: new Security0()
      })

      await this.provisioner.connect()
      this.deviceName = this.provisioner.device?.name || "Unknown"

      this.pushEvent("ble_status", { status: "establishing", message: "Establishing session..." })
      await this.provisioner.establishSession()

      this.pushEvent("ble_connected", { deviceName: this.deviceName })

    } catch (error) {
      console.error('BLE connection error:', error)
      this.provisioner = null
      this.pushEvent("ble_error", { message: error.message || "Connection failed" })
    }
  },

  async disconnect() {
    if (this.provisioner) {
      try {
        await this.provisioner.disconnect()
      } catch (e) {
        // Ignore disconnect errors
      }
      this.provisioner = null
    }
    this.pushEvent("ble_disconnected", {})
  },

  async provision({ ssid, password, apiUrl, apiToken }) {
    if (!this.provisioner) {
      this.pushEvent("ble_error", { message: "Not connected to device" })
      return
    }

    try {
      const encoder = new TextEncoder()

      // Step 1: Send API configuration to custom endpoint
      this.pushEvent("ble_status", { status: "provisioning", message: "Sending API configuration..." })
      const apiConfig = JSON.stringify({ api_url: apiUrl, api_token: apiToken })
      await this.provisioner.writeValueToEndpoint('api-config', encoder.encode(apiConfig))

      // Step 2: Send WiFi credentials
      this.pushEvent("ble_status", { status: "provisioning", message: "Sending WiFi credentials..." })
      await this.provisioner.sendCredentials({
        ssid: encoder.encode(ssid),
        passphrase: encoder.encode(password)
      })

      // Success! Device will save config and reboot
      this.pushEvent("ble_provisioned", { deviceName: this.deviceName })
      this.provisioner = null

    } catch (error) {
      console.error('BLE provisioning error:', error)
      // Some errors occur even on success (device disconnects during reboot)
      // Check if it might be a success case
      if (error.message?.includes('GATT') || error.message?.includes('disconnect')) {
        // This often happens on successful provisioning when device reboots
        this.pushEvent("ble_provisioned", { deviceName: this.deviceName, warning: "Device may have rebooted (this is normal)" })
        this.provisioner = null
      } else {
        this.pushEvent("ble_error", { message: error.message || "Provisioning failed" })
      }
    }
  }
}

export default BluetoothProvisioning
