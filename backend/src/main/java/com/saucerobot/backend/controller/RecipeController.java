package com.saucerobot.backend.controller;

import com.saucerobot.backend.entity.Recipe;
import com.saucerobot.backend.service.RecipeService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/recipes")
@CrossOrigin(origins = {"http://localhost:3000", "http://192.168.1.220:3000" })  // allows your React app
public class RecipeController {

    @Autowired
    private RecipeService recipeService;

    @GetMapping
    public List<Recipe> getAllRecipes() {
        return recipeService.getAllRecipes();
    }

    @PostMapping
    public ResponseEntity<Recipe> createRecipe(@RequestBody Recipe recipe) {
        Recipe saved = recipeService.save(recipe);
        return ResponseEntity.ok(saved);
    }

    @PatchMapping("/{id}/name")
    public ResponseEntity<Void> updateRecipeName(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {

        String newName = request.get("name");

        if (newName == null || newName.trim().isEmpty()) {
            return ResponseEntity.badRequest().build(); // 400
        }

        recipeService.updateRecipeName(id, newName.trim());

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/start-sauce/{id}")
    public ResponseEntity<String> startSauce(@PathVariable Long id) {
        String message = recipeService.getRecipeNameById(id) + " IS BEING MADE...";
        return ResponseEntity.ok(message);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Recipe> updateRecipe(
            @PathVariable Long id,
            @RequestBody Recipe updatedRecipe) {

        Recipe existing = recipeService.findById(id);
        existing.setName(updatedRecipe.getName());
        existing.setIngredients(updatedRecipe.getIngredients());

        Recipe saved = recipeService.save(existing);
        return ResponseEntity.ok(saved);
    }

}