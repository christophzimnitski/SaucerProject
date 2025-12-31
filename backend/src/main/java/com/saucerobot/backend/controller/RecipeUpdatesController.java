package com.saucerobot.backend.controller;

import com.saucerobot.backend.dto.RecipeResponse;
import com.saucerobot.backend.event.RecipeChangedEvent;
import com.saucerobot.backend.mapper.RecipeMapper;
import org.springframework.context.event.EventListener;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@RestController
public class RecipeUpdatesController {
    //Connections listen here
    private final List<SseEmitter> emitters = new CopyOnWriteArrayList<>();
    private final RecipeMapper recipeMapper;

    public RecipeUpdatesController(RecipeMapper recipeMapper) {
        this.recipeMapper = recipeMapper;
    }

    @GetMapping("/api/recipes/stream")
    public SseEmitter streamRecipes() {
        SseEmitter emitter = new SseEmitter(Long.MAX_VALUE);
        emitters.add(emitter);

        emitter.onCompletion(() -> emitters.remove(emitter));
        emitter.onTimeout(() -> emitters.remove(emitter));

        return emitter;
    }

    @EventListener
    public void onRecipeChanged(RecipeChangedEvent event) {
        List<SseEmitter> deadEmitters = new ArrayList<>();
        RecipeResponse updated = recipeMapper.toResponse(event.getRecipe());

        emitters.forEach(emitter -> {
            try {
                emitter.send(updated);
            } catch (Exception e) {
                deadEmitters.add(emitter);
            }
        });
        emitters.removeAll(deadEmitters);
    }
}