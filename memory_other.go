//go:build !windows

package main

func availableMemoryBytes() uint64 { return ^uint64(0) }
