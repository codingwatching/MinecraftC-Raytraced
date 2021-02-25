#pragma once

#ifdef __APPLE__
	#include <OpenCL/cl.h>
	#include <OpenCL/cl_gl.h>
	#include <OpenCL/cl_gl_ext.h>
#else
	#include <CL/cl.h>
	#include <CL/cl_gl.h>
#endif
