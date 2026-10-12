//go:build windows

package main

import (
	"syscall"
	"unsafe"
)

type memoryStatusEx struct {
	Length               uint32
	MemoryLoad           uint32
	TotalPhys            uint64
	AvailPhys            uint64
	TotalPageFile        uint64
	AvailPageFile        uint64
	TotalVirtual         uint64
	AvailVirtual         uint64
	AvailExtendedVirtual uint64
}

func availableMemoryBytes() uint64 {
	var m memoryStatusEx
	m.Length = uint32(unsafe.Sizeof(m))
	dll := syscall.NewLazyDLL("kernel32.dll")
	proc := dll.NewProc("GlobalMemoryStatusEx")
	ret, _, _ := proc.Call(uintptr(unsafe.Pointer(&m)))
	if ret == 0 {
		return 0
	}
	return m.AvailPhys
}
