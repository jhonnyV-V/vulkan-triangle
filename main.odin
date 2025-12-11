#+feature dynamic-literals
package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import "vendor:glfw"
import "vendor:vulkan"

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.println(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if (key == glfw.KEY_ESCAPE && action == glfw.PRESS) ||
	   (key == glfw.KEY_Q && action == glfw.PRESS) {
		glfw.SetWindowShouldClose(window, glfw.TRUE)
	}
}

debugCallback :: proc "c" (
	severity: vulkan.DebugUtilsMessageSeverityFlagsEXT,
	type: vulkan.DebugUtilsMessageTypeFlagsEXT,
	callbackData: ^vulkan.DebugUtilsMessengerCallbackDataEXT,
	ptr: rawptr,
) -> b32 {
	context = runtime.default_context()
	fmt.printf("validation layer type %s\n msg: %\n", type, callbackData.pMessage)

	return false
}

vkInstance: vulkan.Instance = vulkan.Instance{}
vkAppInfo: vulkan.ApplicationInfo = {
	sType              = vulkan.StructureType.APPLICATION_INFO,
	pApplicationName   = "Triangle",
	applicationVersion = vulkan.MAKE_VERSION(1, 0, 0),
	pEngineName        = "no engine",
	apiVersion         = vulkan.MAKE_VERSION(1, 3, 280),
}
vkInstanceInfo: vulkan.InstanceCreateInfo = {
	sType             = vulkan.StructureType.INSTANCE_CREATE_INFO,
	pApplicationInfo  = &vkAppInfo,
	enabledLayerCount = 0,
}
vkDebugMessenger: vulkan.DebugUtilsMessengerEXT

WIDTH: c.int : 800
HEIGHT: c.int : 600

validationLayers := [1]cstring{"VK_LAYER_KHRONOS_validation"}
enableValidationLayers :: ODIN_DEBUG
physicalDevice: vulkan.PhysicalDevice

setupDebugMessenger :: proc() {
	if !enableValidationLayers {
		return
	}
	severity: vulkan.DebugUtilsMessageSeverityFlagsEXT = {.VERBOSE, .WARNING, .ERROR}
	messageType: vulkan.DebugUtilsMessageTypeFlagsEXT = {.GENERAL, .PERFORMANCE, .VALIDATION}
	debugInfo: vulkan.DebugUtilsMessengerCreateInfoEXT = {
		messageSeverity = severity,
		messageType     = messageType,
		pfnUserCallback = debugCallback,
	}

	result := vulkan.CreateDebugUtilsMessengerEXT(vkInstance, &debugInfo, nil, &vkDebugMessenger)

	if result != .SUCCESS {
		fmt.panicf("failed to attach debug callback")
	}
}

checkValidationLayerSupport :: proc() -> bool {
	extensionCount: u32 = 0
	vulkan.EnumerateInstanceLayerProperties(&extensionCount, nil)
	layers := make_slice([]vulkan.LayerProperties, int(extensionCount))
	defer delete(layers)
	vulkan.EnumerateInstanceLayerProperties(&extensionCount, &layers[0])

	allLayersFound := true
	for requiredLayer in validationLayers {
		foundLayer := false
		for layer in layers {
			layerBytes: [256]byte = auto_cast layer.layerName
			layerName, err := strings.clone_from_bytes(layerBytes[:], context.temp_allocator)
			assert(err == .None, "Failed to clone layer name")
			layerName = strings.trim_right_null(layerName)

			if strings.compare(layerName, string(requiredLayer)) == 0 {
				foundLayer = true
			}
		}

		if !foundLayer {
			allLayersFound = false
		}
	}

	free_all(context.temp_allocator)

	return allLayersFound
}

//https://www.glfw.org/docs/3.3/vulkan_guide.html
createVkInstance :: proc() {
	requiredExtensions := glfw.GetRequiredInstanceExtensions()

	if enableValidationLayers {
		biggerExtensions := make([]cstring, len(requiredExtensions) + 1)
		copy(biggerExtensions, requiredExtensions)

		biggerExtensions[len(requiredExtensions)] = vulkan.EXT_DEBUG_UTILS_EXTENSION_NAME
		requiredExtensions = biggerExtensions
	}

	vulkan.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	assert(vulkan.CreateInstance != nil, "CreateInstance is nil")

	vkInstanceInfo.enabledExtensionCount = u32(len(requiredExtensions))
	vkInstanceInfo.ppEnabledExtensionNames = &requiredExtensions[0]

	assert(
		!enableValidationLayers || (enableValidationLayers && checkValidationLayerSupport()),
		"validation layers requested, but not available!",
	)
	if enableValidationLayers {
		vkInstanceInfo.ppEnabledLayerNames = &validationLayers[0]
		vkInstanceInfo.enabledLayerCount = len(validationLayers)
	}

	assert(&vkInstanceInfo != nil, "instance info is nil")
	result := vulkan.CreateInstance(&vkInstanceInfo, nil, &vkInstance)

	if result != vulkan.Result.SUCCESS {
		fmt.printf("failed to create vulkan instance %s\n", result)
		panic("")
	}

	vulkan.load_proc_addresses_instance(vkInstance)

	// extensionCount: u32 = 0
	// vulkan.EnumerateInstanceExtensionProperties(nil, &extensionCount, nil)
	// extensions := make_slice([]vulkan.ExtensionProperties, int(extensionCount))
	// defer delete(extensions)
	// vulkan.EnumerateInstanceExtensionProperties(nil, &extensionCount, &extensions[0])
	//
	// for extension in extensions {
	// 	fmt.printf("extension: %s\n", extension.extensionName)
	// }
}

pickPhysycalDevice :: proc() {
	count: u32 = 0

	vulkan.EnumeratePhysicalDevices(vkInstance, &count, nil)
	if count == 0 {
		fmt.panicf("vulkan: no GPU found")
	}

	deviceList := make([]vulkan.PhysicalDevice, count, context.temp_allocator)
	vulkan.EnumeratePhysicalDevices(vkInstance, &count, raw_data(deviceList))

	bestDeviceScore := -1
	for device in deviceList {
		score := 0
		props: vulkan.PhysicalDeviceProperties

		vulkan.GetPhysicalDeviceProperties(device, &props)
		name := byte_arr_str(&props.deviceName)

		features: vulkan.PhysicalDeviceFeatures
		vulkan.GetPhysicalDeviceFeatures(device, &features)

		features.geometryShader or_continue

		switch props.deviceType {
		case .DISCRETE_GPU:
			score += 300_000

		case .INTEGRATED_GPU:
			score += 200_000

		case .VIRTUAL_GPU:
			score += 100_000

		case .OTHER, .CPU:
		}

		score += int(props.limits.maxImageDimension2D)

		if score > bestDeviceScore {
			physicalDevice = device
		}
	}
}

main :: proc() {
	glfw.SetErrorCallback(error_callback)

	if !glfw.Init() {
		fmt.println("Failed to initialize GLFW")
		return
	}
	defer glfw.Terminate()

	if !glfw.VulkanSupported() {
		fmt.println("Vulkan is not supported")
		return
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	window := glfw.CreateWindow(WIDTH, HEIGHT, "Triangle", nil, nil)

	if window == nil {
		fmt.println("Failed to create GLFW window")
		return
	}
	defer glfw.DestroyWindow(window)

	createVkInstance()
	defer vulkan.DestroyInstance(vkInstance, nil)
	setupDebugMessenger()
	pickPhysycalDevice()

	glfw.SetKeyCallback(window, key_callback)
	// glfw.MakeContextCurrent(window)
	// glfw.SwapInterval(1)

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()
		// glfw.SwapBuffers(window)
	}

}

byte_arr_str :: proc(arr: ^[$N]byte) -> string {
	return strings.truncate_to_byte(string(arr[:]), 0)
}
