package com.plaud.nicebuild.ui

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.plaud.nicebuild.R
import com.plaud.nicebuild.adapter.DeviceAdapter
import com.plaud.nicebuild.ble.BleCore
import com.plaud.nicebuild.ble.BleManager
import com.plaud.nicebuild.utils.LoadingDialog
import com.plaud.nicebuild.viewmodel.MainViewModel

class DeviceListFragment : Fragment() {
    private lateinit var deviceAdapter: DeviceAdapter
    private lateinit var rvDeviceList: RecyclerView
    private lateinit var mainViewModel: MainViewModel
    private lateinit var bleManager: BleManager
    private lateinit var bleCore: BleCore
    private var scanHandler: Handler? = null
    private var scanRunnable: Runnable? = null
    private var connectionTimeoutHandler: Handler? = null
    private var connectionTimeoutRunnable: Runnable? = null
    private lateinit var tvStatus: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bleManager = BleManager.getInstance(requireContext())
        bleCore = BleCore.getInstance(requireContext())
        mainViewModel = ViewModelProvider(requireActivity()).get(MainViewModel::class.java)

        requireActivity().onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                bleCore.startScan(false)
                scanRunnable?.let { scanHandler?.removeCallbacks(it) }
                findNavController().popBackStack()
            }
        })
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_device_list, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        activity?.window?.statusBarColor = ContextCompat.getColor(requireContext(), R.color.background_secondary)
        @Suppress("DEPRECATION")
        activity?.window?.decorView?.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR

        val toolbar = view.findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.setNavigationOnClickListener {
            activity?.onBackPressedDispatcher?.onBackPressed()
        }

        rvDeviceList = view.findViewById(R.id.rv_device_list)
        tvStatus = view.findViewById(R.id.tv_status)
        val btnRescan = view.findViewById<MaterialButton>(R.id.btn_rescan)
        btnRescan.setOnClickListener { startScan() }
        
        setupRecyclerView()
        observeViewModel()
    }

    override fun onResume() {
        super.onResume()
        activity?.window?.statusBarColor = ContextCompat.getColor(requireContext(), R.color.background_secondary)
        @Suppress("DEPRECATION")
        activity?.window?.decorView?.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        startScan()
    }

    override fun onPause() {
        super.onPause()
        activity?.window?.statusBarColor = ContextCompat.getColor(requireContext(), R.color.white)
        @Suppress("DEPRECATION")
        activity?.window?.decorView?.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        bleCore.stopScan()
        scanRunnable?.let { scanHandler?.removeCallbacks(it) }
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        bleCore.stopScan()
        scanRunnable?.let { runnable ->
            scanHandler?.removeCallbacks(runnable)
        }
        // Clean up connection timeout handler
        connectionTimeoutRunnable?.let { connectionTimeoutHandler?.removeCallbacks(it) }
        LoadingDialog.hide()
        mainViewModel.updateDeviceList(emptyList())
    }

    private fun setupRecyclerView() {
        deviceAdapter = DeviceAdapter()
        rvDeviceList.layoutManager = LinearLayoutManager(requireContext())
        rvDeviceList.adapter = deviceAdapter

        deviceAdapter.setOnItemClickListener { device ->
            if (!isAdded) return@setOnItemClickListener
            
            // Prevent duplicate clicks: check if loading
            if (mainViewModel.isLoading.value == true) {
                Log.d("DeviceListFragment", "Connection already in progress, ignoring click")
                return@setOnItemClickListener
            }
            
            Log.d("DeviceListFragment", "Starting connection to device: ${device.name}")
            mainViewModel.setLoading(true)

            // Set connection timeout handler (30 seconds timeout)
            connectionTimeoutHandler = Handler(Looper.getMainLooper())
            connectionTimeoutRunnable = Runnable {
                if (mainViewModel.isLoading.value == true) {
                    Log.w("DeviceListFragment", "Connection timeout, re-enabling buttons")
                    mainViewModel.setLoading(false)
                    deviceAdapter.enableAllConnectButtons()
                    if (isAdded) {
                        Toast.makeText(requireContext(), getString(R.string.connection_timeout_retry), Toast.LENGTH_SHORT).show()
                    }
                }
            }
            connectionTimeoutHandler?.postDelayed(connectionTimeoutRunnable!!, 30000L)

            // Use background thread to handle connection, avoid blocking UI
            bleManager.connectDevice(device) { success, code, message ->
                if (!isAdded) return@connectDevice
                
                // Ensure UI updates are executed on main thread
                requireActivity().runOnUiThread {
                    // Clear timeout handler
                    connectionTimeoutRunnable?.let { connectionTimeoutHandler?.removeCallbacks(it) }
                    
                    mainViewModel.setLoading(false)
                    
                    // Re-enable all connect buttons
                    deviceAdapter.enableAllConnectButtons()
                    
                    if (success) {
                        Toast.makeText(requireContext(), getString(R.string.toast_connect_successful), Toast.LENGTH_SHORT).show()
                        mainViewModel.setCurrentDevice(device)
                        if (findNavController().currentDestination?.id != R.id.deviceFeatureFragment) {
                            findNavController().navigate(R.id.action_deviceList_to_feature)
                        }
                    } else {
                        Log.e("DeviceListFragment", "Connection failed: code=$code, message=$message")
                        Toast.makeText(requireContext(), getString(R.string.toast_connect_failed_with_reason, message ?: "", code ?: ""), Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }

    private fun observeViewModel() {
        mainViewModel.isLoading.observe(viewLifecycleOwner) { isLoading ->
            if (!isAdded) return@observe
            if (isLoading) {
                LoadingDialog.show(requireContext(), getString(R.string.loading_toast_connecting))
            } else {
                LoadingDialog.hide()
            }
        }

        mainViewModel.deviceList.observe(viewLifecycleOwner) { devices ->
            deviceAdapter.updateDevices(devices)
            tvStatus.text = getString(R.string.status_devices_found_formatted, devices.size)
        }
    }

    private fun startScan() {
        if (!isAdded) return
        tvStatus.text = getString(R.string.fragment_device_list_scanning_status)
        scanRunnable?.let { scanHandler?.removeCallbacks(it) }
        bleCore.clearDeviceList()

        bleCore.startScan(true) { devices ->
            if (!isAdded) return@startScan
            val sortedDevices = devices.sortedByDescending { it.rssi }
            mainViewModel.updateDeviceList(sortedDevices)
        }

        scanHandler = Handler(Looper.getMainLooper())
        scanRunnable = Runnable {
            if (!isAdded) return@Runnable
            bleCore.startScan(false)
        }
        scanHandler?.postDelayed(scanRunnable!!, 10_000)
    }
} 