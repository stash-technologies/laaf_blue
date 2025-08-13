package com.example.blue

import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar

class BluePluginRegistrant {
    companion object {
        @JvmStatic
        fun registerWith(registry: PluginRegistry) {
            if (alreadyRegisteredWith(registry)) {
                return
            }
            BluePlugin().onAttachedToEngine(registry.registrarFor("com.example.blue").messenger())
        }

        private fun alreadyRegisteredWith(registry: PluginRegistry): Boolean {
            val key = BluePluginRegistrant::class.java.canonicalName
            if (registry.hasPlugin(key)) {
                return true
            }
            registry.registrarFor(key)
            return false
        }
    }
}
