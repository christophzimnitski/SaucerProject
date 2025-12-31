package com.saucerobot.backend.service;

import com.saucerobot.backend.entity.Recipe;
import com.saucerobot.backend.repository.RecipeRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class RecipeService {

    private final RecipeRepository recipeRepository;

    public RecipeService(RecipeRepository recipeRepository) {
        this.recipeRepository = recipeRepository;
    }

    public List<Recipe> getAllRecipes() {
        return recipeRepository.findAll();
    }

    public Recipe save(Recipe recipe) {
        return recipeRepository.save(recipe);
    }

    public String getRecipeNameById(Long id) {
        return recipeRepository.findById(id)
                .map(Recipe::getName)
                .orElse("UNKNOWN SAUCE");
    }

    public Recipe findById(Long id) {
        Optional<Recipe> optional = recipeRepository.findById(id);
        if (optional.isEmpty()) {
            throw new RuntimeException("Recipe not found with id: " + id);
        }
        return optional.get();
    }

    public void deleteById(Long id) {
        recipeRepository.deleteById(id);
    }

    public void updateRecipeName(Long id, String newName) {
        Recipe recipe = recipeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Recipe not found: " + id));

        Recipe updatedRecipe = new Recipe(
                newName, //changes name
                recipe.getIngredients() //preserves the same ingredients
        );
        updatedRecipe.setId(id);  //preserves the same ID

        recipeRepository.save(updatedRecipe);
    }
}