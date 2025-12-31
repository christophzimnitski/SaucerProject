package com.saucerobot.backend.dto;

import java.util.List;

public record RecipeRequest(String name, List<String> ingredients) {}