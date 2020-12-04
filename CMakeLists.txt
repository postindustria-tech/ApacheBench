cmake_minimum_required(VERSION 3.10)
#set (CMAKE_C_STANDARD 11)
#set (CMAKE_CXX_STANDARD 11)

#set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/modules ${CMAKE_MODULE_PATH})

project(AB LANGUAGES C)

#find_package(APRUTIL REQUIRED)

# Find APR includes and libraries.

FIND_PATH(APR_INCLUDE_DIR apr.h
        /opt/homebrew/opt/apr/include/apr-1
        /usr/local/include/apr-1
        /usr/local/include/apr-1.0
        /usr/include/apr-1
        /usr/include/apr-1.0
        /usr/local/apr/include/apr-1
        )

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

IF (APR_LIBRARY AND APR_INCLUDE_DIR)
    SET(APR_FOUND "YES")
ELSE (APR_LIBRARY AND APR_INCLUDE_DIR)
    SET(APR_FOUND "NO")
ENDIF (APR_LIBRARY AND APR_INCLUDE_DIR)


IF (APR_FOUND)
    IF (NOT APR_FIND_QUIETLY)
        MESSAGE(STATUS "Found APR headers: ${APR_INCLUDE_DIR}")
        MESSAGE(STATUS "Found APR library: ${APR_LIBRARY}")
    ENDIF (NOT APR_FIND_QUIETLY)
ELSE (APR_FOUND)
    IF (APR_FIND_REQUIRED)
        MESSAGE(FATAL_ERROR "Could not find APR library")
    ENDIF (APR_FIND_REQUIRED)
ENDIF (APR_FOUND)

# Find APR Util includes and libraries

FIND_PATH(APRUTIL_INCLUDE_DIR apu.h
        /opt/homebrew/opt/apr-util/include/apr-1
        /usr/local/include/apr-1
        /usr/local/include/apr-1.0
        /usr/include/apr-1
        /usr/include/apr-1.0
        /usr/local/apr/include/apr-1
        )

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




set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

add_executable(ab ${CMAKE_CURRENT_LIST_DIR}/ab.c ${CMAKE_CURRENT_LIST_DIR}/ap_release.h)
target_include_directories(ab PRIVATE ${APR_INCLUDE_DIR})
target_link_libraries(ab ${APR_LIBRARY} ${APRUTIL_LIBRARY} m c)
