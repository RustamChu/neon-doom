"""Headless smoke test.

Boots the game with the dummy SDL drivers, plays a couple of hundred frames,
exercises shooting, dying and winning, and saves a screenshot. Run it with:

    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy python tests/smoke_test.py
"""
import os
import sys
import time

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pygame as pg  # noqa: E402

from main import Game, PLAY, MENU, DEAD, WIN  # noqa: E402
from settings import ENEMY_TYPES  # noqa: E402


def frames(game, count, dt=16):
    for _ in range(count):
        game.update()
        game.draw()
        game.delta_time = dt


def main():
    game = Game()

    # --- menu renders, difficulty can be switched -------------------------
    assert game.state == MENU
    game.draw()
    game._on_key(pg.K_3)
    assert game.difficulty["name"] == "NIGHTMARE"
    game._on_key(pg.K_2)
    assert game.difficulty["name"] == "NORMAL"

    # --- start a round ----------------------------------------------------
    game.start_round()
    assert game.state == PLAY
    assert len(game.npcs) == 5, "the map should spawn 5 demons"
    assert len({n.kind for n in game.npcs}) == len(ENEMY_TYPES), \
        "all demon types should appear"

    # frame a nice view, then grab the screenshot mid muzzle-flash
    game.player.x, game.player.y = 2.5, 5.5
    game.player.angle = -0.15
    out = os.path.join(os.path.dirname(__file__), "..", "docs", "screenshot.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    frames(game, 20)
    game.weapon.fire()
    frames(game, 1)
    pg.image.save(game.screen, out)
    frames(game, 60)

    assert game.player.health > 0, "player should still be alive"
    assert game.raycasting.ray_casting_result, "the raycaster produced no walls"
    assert 0 < game.raycasting.center_depth() < 30

    # --- walls actually stop the player -----------------------------------
    game.player.x, game.player.y = 1.5, 1.5
    game.player.angle = 3.14159   # face the west wall
    for _ in range(40):
        game.player._try_move(-0.05, 0.0)
    assert game.player.x > 1.0, "player walked through a wall"

    # --- damage and death of a demon --------------------------------------
    npc = game.npcs[0]
    before = npc.health
    npc.take_damage(45)
    assert npc.health < before, "the demon must take damage"
    npc.take_damage(9999)
    assert npc.dying or not npc.alive, "the demon must die from massive damage"

    # --- victory path ------------------------------------------------------
    score_before = game.score
    for npc in game.npcs:
        npc.take_damage(9999)
    assert game.score > score_before, "kills must award score"
    for _ in range(300):
        game.update()
        game.draw()
        game.delta_time = 40
        if game.state == WIN:
            break
    assert game.state == WIN, "killing every demon must trigger the victory screen"
    game.draw()

    # --- player death path -------------------------------------------------
    game.start_round()
    game.player.take_damage(9999)
    assert game.state == DEAD, "lethal damage must trigger game over"
    frames(game, 2)

    # --- pickups -----------------------------------------------------------
    game.start_round()
    gem = next(p for p in game.pickups if p.kind == "gem")
    game.player.x, game.player.y = gem.x, gem.y
    gem.update()
    assert gem.collected, "walking into a gem must pick it up"

    # --- rough performance check -------------------------------------------
    game.start_round()
    start = time.perf_counter()
    frames(game, 60)
    ms = (time.perf_counter() - start) / 60 * 1000
    print(f"average frame: {ms:.1f} ms")

    print("smoke test OK - screenshot saved to", os.path.normpath(out))


if __name__ == "__main__":
    main()
