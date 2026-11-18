/* Sello de arranque Allahu Corp para ports SDL2 de la RG35XX.
   Uso: sello imagen.bmp [ms_visible]   - fundido de entrada/salida, se salta con cualquier boton */
#include <SDL2/SDL.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    if (argc < 2) return 1;
    int hold = argc > 2 ? atoi(argv[2]) : 1500;
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0) return 1;
    SDL_Window *w = SDL_CreateWindow("sello", 0, 0, 640, 480, SDL_WINDOW_FULLSCREEN);
    SDL_Renderer *r = w ? SDL_CreateRenderer(w, -1, 0) : NULL;
    SDL_Surface *s = SDL_LoadBMP(argv[1]);
    if (!r || !s) { SDL_Quit(); return 1; }
    for (int i = 0; i < SDL_NumJoysticks(); i++) if (SDL_IsGameController(i)) SDL_GameControllerOpen(i);
    SDL_Texture *t = SDL_CreateTextureFromSurface(r, s);
    SDL_SetTextureBlendMode(t, SDL_BLENDMODE_BLEND);
    SDL_Rect d = { (640 - s->w) / 2, (480 - s->h) / 2, s->w, s->h };
    const int fade = 500, total = fade * 2 + hold;
    Uint32 t0 = SDL_GetTicks();
    for (;;) {
        SDL_Event e; int skip = 0;
        while (SDL_PollEvent(&e))
            if (e.type == SDL_KEYDOWN || e.type == SDL_CONTROLLERBUTTONDOWN || e.type == SDL_JOYBUTTONDOWN || e.type == SDL_QUIT) skip = 1;
        int el = (int)(SDL_GetTicks() - t0);
        if (skip || el >= total) break;
        int a = el < fade ? el * 255 / fade : (el > fade + hold ? (total - el) * 255 / fade : 255);
        SDL_SetRenderDrawColor(r, 0, 0, 0, 255);
        SDL_RenderClear(r);
        SDL_SetTextureAlphaMod(t, (Uint8)a);
        SDL_RenderCopy(r, t, NULL, &d);
        SDL_RenderPresent(r);
        SDL_Delay(16);
    }
    SDL_Quit();
    return 0;
}
