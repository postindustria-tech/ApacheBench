cmake_minimum_required(VERSION 3.10)

project(AB LANGUAGES C)

function(download_file url filename)

if(NOT EXISTS ${filename})
    file(DOWNLOAD ${url} ${filename}
	    HTTPHEADER "User-Agent: CMake"
        TLS_VERIFY ON)
endif()

endfunction(download_file)

download_file(
    https://media.githubusercontent.com/media/51Degrees/device-detection-data/master/20000%20User%20Agents.csv
    ${CMAKE_SOURCE_DIR}/uas.csv
)

IF (MSVC)
	# Get the platform
	IF(CMAKE_VS_PLATFORM_NAME STREQUAL x64)
		SET(APACHE_DL_PLAT 64)
	ELSE(CMAKE_VS_PLATFORM_NAME STREQUAL x64)
		SET(APACHE_DL_PLAT 32)
	ENDIF(CMAKE_VS_PLATFORM_NAME STREQUAL x64)
	
	# Get the VS version
	IF(MSVC_TOOLSET_VERSION STREQUAL 142)
		SET(APACHE_DL_VS VS16)
	ELSEIF(MSVC_TOOLSET_VERSION STREQUAL 141)
		SET(APACHE_DL_VS VC15)
	ELSE()
		MESSAGE(FATAL_ERROR "Visual Studio was not version 2017 or 2019")
	ENDIF()
	
	# Download the appropriate apache source code
	download_file(
		https://www.apachelounge.com/download/${APACHE_DL_VS}/binaries/httpd-2.4.48-win${APACHE_DL_PLAT}-${APACHE_DL_VS}.zip
		${CMAKE_CURRENT_BINARY_DIR}/apr.zip
	)
	SET(APACHE_DIR ${CMAKE_CURRENT_BINARY_DIR}/Apache24)
	FILE(ARCHIVE_EXTRACT INPUT ${CMAKE_CURRENT_BINARY_DIR}/apr.zip)
	
	SET(APR_INCLUDE_DIR ${APACHE_DIR}/include)
	SET(APR_LIBRARY ${APACHE_DIR}/lib/libapr-1.lib)
	SET(APRUTIL_LIBRARY ${APACHE_DIR}/lib/libaprutil-1.lib)
ELSE (MSVC)
	# Find APR includes
	FIND_PATH(APR_INCLUDE_DIR apr.h
		/opt/homebrew/opt/apr/include/apr-1
		/usr/local/include/apr-1
		/usr/local/include/apr-1.0
		/usr/include/apr-1
		/usr/include/apr-1.0
		/usr/local/apr/include/apr-1
		)

	# Find APR library
	SET(APR_NAMES ${APR_NAMES} apr-1)
	FIND_LIBRARY(APR_LIBRARY
		NAMES ${APR_NAMES}
		HINTS
		/opt/homebrew/opt/apr/lib
		PATHS
		/usr/lib
		/usr/local/lib
		/usr/local/apr/lib
		)

	# Check both were found
	IF (APR_LIBRARY AND APR_INCLUDE_DIR)
		SET(APR_FOUND "YES")
	ELSE (APR_LIBRARY AND APR_INCLUDE_DIR)
		SET(APR_FOUND "NO")
	ENDIF (APR_LIBRARY AND APR_INCLUDE_DIR)

	IF (APR_FOUND)
		MESSAGE(STATUS "Found APR headers: ${APR_INCLUDE_DIR}")
		MESSAGE(STATUS "Found APR library: ${APR_LIBRARY}")
	ELSE (APR_FOUND)
		MESSAGE(FATAL_ERROR "Could not find APR library")
	ENDIF (APR_FOUND)

	# Find APR Util includes
	FIND_PATH(APRUTIL_INCLUDE_DIR apu.h
		/opt/homebrew/opt/apr-util/include/apr-1
		/usr/local/include/apr-1
		/usr/local/include/apr-1.0
		/usr/include/apr-1
		/usr/include/apr-1.0
		/usr/local/apr/include/apr-1
		)

	# Find APR Util library
	SET(APRUTIL_NAMES ${APRUTIL_NAMES} aprutil-1)
	FIND_LIBRARY(APRUTIL_LIBRARY
		NAMES ${APRUTIL_NAMES}
		HINTS
		/opt/homebrew/opt/apr-util/lib
		PATHS
		/usr/lib
		/usr/local/lib
		/usr/local/apr/lib
		)

	# Check both were found
	IF (APRUTIL_LIBRARY AND APRUTIL_INCLUDE_DIR)
		SET(APRUTIL_FOUND "YES")
	ELSE (APRUTIL_LIBRARY AND APRUTIL_INCLUDE_DIR)
		SET(APRUTIL_FOUND "NO")
	ENDIF (APRUTIL_LIBRARY AND APRUTIL_INCLUDE_DIR)

	IF (APRUTIL_FOUND)
		IF (NOT APRUTIL_FIND_QUIETLY)
			MESSAGE(STATUS "Found APRUTIL headers: ${APRUTIL_INCLUDE_DIR}")
			MESSAGE(STATUS "Found APRUTIL library: ${APRUTIL_LIBRARY}")
		ENDIF (NOT APRUTIL_FIND_QUIETLY)
	ELSE (APRUTIL_FOUND)
		IF (APRUTIL_FIND_REQUIRED)
			MESSAGE(FATAL_ERROR "Could not find APRUTIL library")
		ENDIF (APRUTIL_FIND_REQUIRED)
	ENDIF (APRUTIL_FOUND)
ENDIF (MSVC)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/bin")

add_executable(ab ${CMAKE_CURRENT_LIST_DIR}/ab.c ${CMAKE_CURRENT_LIST_DIR}/ap_release.h)
target_include_directories(ab PRIVATE ${APR_INCLUDE_DIR})
target_link_libraries(ab ${APR_LIBRARY} ${APRUTIL_LIBRARY})
IF(MSVC)
	# Copy the DLLs from the downloaded Apache
	add_custom_target(CopyDlls
		COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
		COMMAND ${CMAKE_COMMAND} -E copy ${APACHE_DIR}/bin/libapr-1.dll ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
		COMMAND ${CMAKE_COMMAND} -E copy ${APACHE_DIR}/bin/libaprutil-1.dll ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
		COMMAND ${CMAKE_COMMAND} -E copy ${APACHE_DIR}/bin/libapriconv-1.dll ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
		COMMENT "Copying APR DLLs" VERBATIM
	)
	add_dependencies(ab CopyDlls)
ELSE(MSVC)
	target_link_libraries(ab m c)
ENDIF(MSVC)

add_custom_target(perf ALL
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/runPerf.sh ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
	COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/runPerf.ps1 ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
	COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/uas.csv ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
    DEPENDS ${CMAKE_SOURCE_DIR}/runPerf.sh ${CMAKE_SOURCE_DIR}/runPerf.ps1 ${CMAKE_SOURCE_DIR}/uas.csv
    VERBATIM
)
add_dependencies(perf ab)
