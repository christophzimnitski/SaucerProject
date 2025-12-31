package com.saucerobot.backend.dto;

import java.util.List;

public record RecipeResponse(Long id, String name, List<String> ingredients) {}