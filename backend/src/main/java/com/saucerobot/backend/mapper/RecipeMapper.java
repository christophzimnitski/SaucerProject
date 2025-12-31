package com.saucerobot.backend.mapper;

import com.saucerobot.backend.dto.RecipeRequest;
import com.saucerobot.backend.dto.RecipeResponse;
import com.saucerobot.backend.entity.Recipe;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class RecipeMapper {

    public Recipe toEntity(RecipeRequest request) {
        Recipe recipe = new Recipe();
        recipe.setName(request.name());
        recipe.setIngredients(request.ingredients() != null
                ? List.copyOf(request.ingredients())
                : List.of());
        return recipe;
    }

    public RecipeResponse toResponse(Recipe recipe) {
        return new RecipeResponse(
                recipe.getId(),
                recipe.getName(),
                List.copyOf(recipe.getIngredients())
        );
    }

    public void updateEntityFromRequest(RecipeRequest request, Recipe recipe) {
        recipe.setName(request.name());
        if (request.ingredients() != null) {
            recipe.getIngredients().clear();
            recipe.getIngredients().addAll(request.ingredients());
        }
    }
}