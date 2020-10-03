package main

import (
	"fmt"
	"github.com/google/uuid"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
)

func main() {
	mux := http.NewServeMux()

	fs := http.FileServer(http.Dir("./html"))
	mux.Handle("/", fs)
	mux.HandleFunc("/synthesize", synthesize)

	err := http.ListenAndServe(":8080", mux)
	if err != nil {
		log.Fatalln(err)
	}
}

func synthesize(w http.ResponseWriter, r *http.Request) {
	filename := fmt.Sprintf("wavs/%s.wav", uuid.New())

	text, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println(err)
		w.WriteHeader(500)
		return
	}

	args := []string{
		"bin/balcon.exe",
		"-n",
		"IVONA 2 Justin",
		"-t",
		string(text),
		"-w",
		filename,
	}

	cmd := exec.Command("wine", args...)
	cmd.Stdin = r.Body

	err = cmd.Run()
	if err != nil {
		log.Println(err)
		w.WriteHeader(500)
		return
	}

	file, err := os.Open(filename)
	if err != nil {
		log.Println(err)
		w.WriteHeader(500)
		return
	}

	defer func() {
		_ = file.Close()
	}()

	stats, err := file.Stat()
	if err != nil {
		log.Println(err)
		w.WriteHeader(500)
		return
	}

	w.Header().Set("Content-Type", "audio/wav")
	w.Header().Set("Content-Length", fmt.Sprint(stats.Size()))

	_, err = io.Copy(w, file)
	if err != nil {
		log.Println(err)
		w.WriteHeader(500)
		return
	}
}