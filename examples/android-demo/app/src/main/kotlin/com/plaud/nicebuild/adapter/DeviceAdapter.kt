package com.plaud.nicebuild.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.plaud.nicebuild.R
import sdk.penblesdk.entity.BleDevice

class DeviceAdapter : RecyclerView.Adapter<DeviceAdapter.ViewHolder>() {

    private val devices = mutableListOf<BleDevice>()
    private var onItemClickListener: ((BleDevice) -> Unit)? = null
    private var lastClickTime = 0L
    private val CLICK_DEBOUNCE_TIME = 1000L // 1 second anti-duplicate click

    class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val deviceName: TextView = itemView.findViewById(R.id.tv_device_name)
        val deviceSerial: TextView = itemView.findViewById(R.id.tv_device_serial)
        val signalValue: TextView = itemView.findViewById(R.id.tv_signal_value)
        val connectButton: MaterialButton = itemView.findViewById(R.id.btn_connect)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_device, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val device = devices[position]
        holder.deviceName.text = device.name ?: "Unknown Device"
        holder.deviceSerial.text = device.serialNumber ?: ""
        holder.signalValue.text = "${device.rssi} dBm"

        holder.connectButton.setOnClickListener {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastClickTime < CLICK_DEBOUNCE_TIME) {
                // Prevent duplicate clicks
                return@setOnClickListener
            }
            lastClickTime = currentTime
            
            // Disable button to prevent duplicate clicks
            holder.connectButton.isEnabled = false
            
            onItemClickListener?.invoke(device)
            
            // Re-enable button after 1 second
            holder.connectButton.postDelayed({
                holder.connectButton.isEnabled = true
            }, CLICK_DEBOUNCE_TIME)
        }
    }

    override fun getItemCount() = devices.size

    fun updateDevices(newDevices: List<BleDevice>) {
        devices.clear()
        devices.addAll(newDevices)
        notifyDataSetChanged()
    }

    fun setOnItemClickListener(listener: (BleDevice) -> Unit) {
        onItemClickListener = listener
    }
    
    /**
     * Re-enable all connect buttons
     */
    fun enableAllConnectButtons() {
        notifyDataSetChanged()
    }
} 