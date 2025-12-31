package com.saucerobot.backend.event;

import com.saucerobot.backend.entity.Recipe;
import lombok.Getter;
import org.springframework.context.ApplicationEvent;

@Getter
public class RecipeChangedEvent extends ApplicationEvent {
    private final Recipe recipe;

    public RecipeChangedEvent(Object source, Recipe recipe) {
        super(source);
        this.recipe = recipe;
    }
}