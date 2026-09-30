// Command smoke is a tiny Ebitengine game used to check that the packages
// installed by setup-ebitengine are enough to build and run a game.
// It opens a window, draws a few frames and exits.
package main

import (
	"errors"
	"image/color"
	"log"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/audio"
)

// framesToRun is how many frames the game draws before it exits on its own.
const framesToRun = 30

type game struct {
	frames int
}

func (g *game) Update() error {
	g.frames++
	if g.frames >= framesToRun {
		return ebiten.Termination
	}
	return nil
}

func (g *game) Draw(screen *ebiten.Image) {
	screen.Fill(color.NRGBA{0xff, 0x8f, 0xb8, 0xff})
}

func (g *game) Layout(int, int) (int, int) { return 320, 240 }

func main() {
	// Creating the audio context links the platform audio backend (ALSA on Linux).
	_ = audio.NewContext(44100)
	ebiten.SetWindowTitle("setup-ebitengine smoke test")
	if err := ebiten.RunGame(&game{}); err != nil && !errors.Is(err, ebiten.Termination) {
		log.Fatal(err)
	}
	log.Println("smoke test finished")
}
