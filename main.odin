package main

import "core:fmt"
import "core:mem"

import im "odin-imgui"
import "odin-imgui/imgui_impl_glfw"
import "odin-imgui/imgui_impl_opengl3"

import "vendor:glfw"
import gl "vendor:OpenGL"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.println(len(track.allocation_map), "allocations not freed")
				for _, entry in track.allocation_map {
					fmt.println(entry.size, "bytes at", entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

	game_data := create_game_data()
	load_game_data(&game_data, "C:\\Program Files (x86)\\Steam\\steamapps\\common\\ZERO Sievert\\ZS_vanilla\\gamedata")
	defer delete_game_data(&game_data)

	assert(cast(bool)glfw.Init())
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 2)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)

	// Makes the backing window popup less obvious
	glfw.WindowHint(glfw.DECORATED, 0)
	glfw.WindowHint(glfw.TRANSPARENT_FRAMEBUFFER, 1)

	primary_monitor := glfw.GetPrimaryMonitor()
	video_mode := glfw.GetVideoMode(primary_monitor)
	xscale, yscale := glfw.GetMonitorContentScale(primary_monitor)
	monitor_width := f32(video_mode.width) * xscale
	monitor_height := f32(video_mode.height) * yscale

	window := glfw.CreateWindow(250, 250, "Backing window", nil, nil)
	assert(window != nil)
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)
	glfw.SwapInterval(1)
	glfw.HideWindow(window)

	gl.load_up_to(3, 2, proc(p: rawptr, name: cstring) {
		(cast(^rawptr)p)^ = glfw.GetProcAddress(name)
	})

	im.CHECKVERSION()
	im.CreateContext()
	defer im.DestroyContext()
	io := im.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad, .DockingEnable, .ViewportsEnable,}

	style := im.GetStyle()
	style.WindowRounding = 0
	style.Colors[im.Col.WindowBg].w = 1

	im.StyleColorsDark()

	imgui_impl_glfw.InitForOpenGL(window, true)
	defer imgui_impl_glfw.Shutdown()
	imgui_impl_opengl3.Init("#version 150")
	defer imgui_impl_opengl3.Shutdown()

	window_opened := true
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		imgui_impl_opengl3.NewFrame()
		imgui_impl_glfw.NewFrame()
		im.NewFrame()

		im.SetNextWindowPos({monitor_width / 2, monitor_height / 2}, .Once, {0.5, 0.5})
		draw_gui(game_data, &window_opened)
		if !window_opened {
			glfw.SetWindowShouldClose(window, true)
		}

		//im.ShowDemoWindow()
		im.Render()

		display_w, display_h := glfw.GetFramebufferSize(window)
		gl.Viewport(0, 0, display_w, display_h)
		gl.ClearColor(0, 0, 0, 0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		imgui_impl_opengl3.RenderDrawData(im.GetDrawData())

		backup_current_window := glfw.GetCurrentContext()
		im.UpdatePlatformWindows()
		im.RenderPlatformWindowsDefault()
		glfw.MakeContextCurrent(backup_current_window)
		
		glfw.SwapBuffers(window)
	}
}