// Package mobilecore is AsterLink's iOS control transport. It mirrors the
// desktop pipe protocol in cmd/asterlink so Dart can use one request shape for
// every platform; gomobile exposes Call to Swift.
package mobilecore

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"

	"golang.org/x/sys/unix"

	gopeed "github.com/GopeedLab/gopeed/bind/asterlink"
)

var callMu sync.Mutex

// Call runs one engine request and returns its JSON result ("null" when empty).
// Low-level errors may contain signed URLs or local paths, so they stay generic.
func Call(method, args string) (string, error) {
	// Status polls are cheap; serialize everything like the desktop pipe does.
	callMu.Lock()
	defer callMu.Unlock()
	result, err := handle(method, args)
	if err != nil {
		return "", errors.New("下载组件操作失败，请重试并检查下载目录")
	}
	if result == nil {
		return "null", nil
	}
	encoded, err := json.Marshal(result)
	if err != nil {
		return "", errors.New("下载组件响应格式错误")
	}
	return string(encoded), nil
}

func handle(method, raw string) (result any, err error) {
	defer func() {
		if recover() != nil {
			result = nil
			err = errors.New("下载组件处理请求失败")
		}
	}()
	var args struct {
		ID         string `json:"id"`
		StorageDir string `json:"storageDir"`
		CacheDir   string `json:"cacheDir"`
		Key        string `json:"key"`
		Path       string `json:"path"`
	}
	if raw != "" && raw != "null" {
		if json.Unmarshal([]byte(raw), &args) != nil {
			return nil, errors.New("下载请求格式错误")
		}
	}
	decode := func(value string, err error) (any, error) {
		if err != nil {
			return nil, err
		}
		var out any
		return out, json.Unmarshal([]byte(value), &out)
	}
	switch method {
	case "version":
		return map[string]any{"version": gopeed.Version(), "protocol": 1, "taskCacheRoots": true, "sourceNetworkPolicy": true, "parserHttp2": true}, nil
	case "freeSpace":
		bytes, err := availableSpace(args.Path)
		return map[string]any{"bytes": bytes}, err
	case "open":
		err = gopeed.Open(args.StorageDir, args.CacheDir, args.Key)
	case "begin":
		err = gopeed.Begin(raw)
	case "parserRequestStart":
		err = gopeed.StartParserRequest(raw)
	case "parserRequestStatus":
		return decode(gopeed.ParserRequestStatus(args.ID))
	case "parserRequestStop":
		gopeed.StopParserRequest(args.ID)
	case "httpProbeStart":
		err = gopeed.StartHttpProbe(raw)
	case "httpProbeStatus":
		return decode(gopeed.HttpProbeStatus(args.ID))
	case "httpProbeStop":
		gopeed.StopHttpProbe(args.ID)
	case "torrentResolve":
		err = gopeed.ResolveTorrent(raw)
	case "torrentMetadata":
		return decode(gopeed.TorrentMetadata(args.ID))
	case "torrentCancel":
		gopeed.CancelTorrent(args.ID)
	case "torrentStreamStart":
		return decode(gopeed.StartTorrentStream(raw))
	case "torrentStreamStatus":
		return decode(gopeed.TorrentStreamStatus(args.ID))
	case "torrentStreamStop":
		gopeed.StopTorrentStream(args.ID)
	case "torrentStreamInterrupt":
		gopeed.InterruptTorrentStream(args.ID)
	case "snapshot":
		return decode(gopeed.Snapshot(args.ID))
	case "pause":
		err = gopeed.Pause(args.ID)
	case "remove":
		err = gopeed.Remove(args.ID)
	case "close":
		err = gopeed.Close()
	default:
		err = errors.New("未知下载组件请求")
	}
	return result, err
}

func availableSpace(path string) (int64, error) {
	absolute, err := filepath.Abs(path)
	if err != nil {
		return 0, err
	}
	for {
		if _, err := os.Stat(absolute); err == nil {
			break
		}
		parent := filepath.Dir(absolute)
		if parent == absolute {
			return 0, os.ErrNotExist
		}
		absolute = parent
	}
	var stat unix.Statfs_t
	if err := unix.Statfs(absolute, &stat); err != nil {
		return 0, err
	}
	return int64(stat.Bavail) * int64(stat.Bsize), nil
}
