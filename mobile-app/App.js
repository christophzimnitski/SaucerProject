import React, { useEffect, useState } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, Alert, ActivityIndicator,
  TextInput, ScrollView, FlatList, Modal, KeyboardAvoidingView, Platform, Switch
} from 'react-native';
import { NativeModules } from 'react-native';

const { SauceRobotServer } = NativeModules;

const API_BASE_URL = '/api/recipes';

const App = () => {
  const [serverRunning, setServerRunning] = useState(false);
  const [serverUrl, setServerUrl] = useState(null);
  const [loading, setLoading] = useState(true);
  const [serverStatus, setServerStatus] = useState('Initializing...');

  // Recipe management state
  const [recipes, setRecipes] = useState([]);
  const [editingRecipeId, setEditingRecipeId] = useState(null);
  const [isAddingNew, setIsAddingNew] = useState(false);
  const [formName, setFormName] = useState('');
  const [formIngredients, setFormIngredients] = useState([]);
  const [currentIngredient, setCurrentIngredient] = useState('');

  // New features state
  const [keepScreenOn, setKeepScreenOn] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    initializeApp();
  }, []);

  useEffect(() => {
    if (serverRunning) {
      fetchRecipes();
      initializeScreenSetting();
    }
  }, [serverRunning]);

  const initializeApp = async () => {
    try {
      setServerStatus('Copying server files...');
      await copyServerFiles();

      setServerStatus('Starting Sauce Robot server...');
      await startServer();

      setLoading(false);
    } catch (error) {
      console.error('Initialization error:', error);
      Alert.alert('Error', `Failed to initialize Sauce Robot: ${error.message}`);
      setLoading(false);
    }
  };

  const copyServerFiles = async () => {
    try {
      await SauceRobotServer.copyServerFiles();
      console.log('Server files copied successfully');
    } catch (error) {
      console.error('Error copying server files:', error);
      throw error;
    }
  };

  const startServer = async () => {
    try {
      const result = await SauceRobotServer.startServer();
      if (result.success) {
        setServerUrl(result.serverUrl);
        setServerRunning(true);
        console.log('iOS Server started at:', result.serverUrl);
      } else {
        throw new Error(result.error || 'Failed to start server');
      }
    } catch (error) {
      console.error('Error starting server:', error);
      throw error;
    }
  };

  const restartServer = async () => {
    setLoading(true);
    setServerStatus('Restarting server...');
    try {
      await SauceRobotServer.stopServer();
      setServerRunning(false);
      await startServer();
    } catch (error) {
      Alert.alert('Error', 'Failed to restart server');
    }
    setLoading(false);
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await fetchRecipes();
      Alert.alert('Success', 'Recipes refreshed!');
    } catch (error) {
      Alert.alert('Error', 'Failed to refresh recipes');
    }
    setIsRefreshing(false);
  };

  const handleScreenToggle = async (value) => {
    try {
      await SauceRobotServer.setKeepScreenOn(value);
      setKeepScreenOn(value);
      Alert.alert('Success', `Screen will ${value ? 'stay on' : 'turn off normally'}`);
    } catch (error) {
      Alert.alert('Error', 'Failed to change screen setting');
    }
  };

  const initializeScreenSetting = async () => {
    try {
      const result = await SauceRobotServer.getKeepScreenOn();
      setKeepScreenOn(result.keepScreenOn);
    } catch (error) {
      console.log('Could not get screen setting:', error);
    }
  };

  const fetchRecipes = async () => {
    try {
      console.log('Fetching recipes from:', serverUrl + API_BASE_URL);
      const response = await fetch(serverUrl + API_BASE_URL);
      if (!response.ok) throw new Error('Failed to fetch recipes');
      const data = await response.json();
      console.log('Fetched recipes:', data);
      setRecipes(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching recipes:', error);
      Alert.alert('Error', 'Failed to load recipes');
    }
  };

  const resetForm = () => {
    setFormName('');
    setFormIngredients([]);
    setCurrentIngredient('');
  };

  const openEdit = (recipe) => {
    setEditingRecipeId(recipe.id);
    setIsAddingNew(false);
    setFormName(recipe.name);
    setFormIngredients([...(recipe.ingredients || [])]);
    setCurrentIngredient('');
  };

  const openAdd = () => {
    setIsAddingNew(true);
    setEditingRecipeId(null);
    resetForm();
  };

  const closeForm = () => {
    setEditingRecipeId(null);
    setIsAddingNew(false);
    resetForm();
  };

  const addIngredient = () => {
    const trimmed = currentIngredient.trim();
    if (trimmed) {
      setFormIngredients(prev => [...prev, trimmed]);
      setCurrentIngredient('');
    }
  };

  const removeIngredient = (index) => {
    setFormIngredients(prev => prev.filter((_, i) => i !== index));
  };

  const saveRecipe = async () => {
    const name = formName.trim();
    if (!name || formIngredients.length === 0) {
      Alert.alert('Error', 'Need a name and at least one ingredient!');
      return;
    }

    const payload = { name, ingredients: formIngredients };
    const url = isAddingNew
      ? serverUrl + API_BASE_URL
      : `${serverUrl}${API_BASE_URL}/${editingRecipeId}`;
    const method = isAddingNew ? 'POST' : 'PUT';

    try {
      const response = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (!response.ok) throw new Error('Save failed');

      const saved = await response.json();
      if (isAddingNew) {
        setRecipes(prev => [...prev, saved]);
      } else {
        setRecipes(prev => prev.map(r => r.id === editingRecipeId ? saved : r));
      }
      closeForm();
    } catch (err) {
      console.error('Save failed:', err);
      Alert.alert('Error', 'Save failed — check console');
    }
  };

  const startSauce = async (recipeId) => {
    try {
      const response = await fetch(`${serverUrl}${API_BASE_URL}/start-sauce/${recipeId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      if (!response.ok) throw new Error('Failed to start sauce');
      const message = await response.text();
      Alert.alert('Success', message);
    } catch (err) {
      console.error('Start sauce failed:', err);
      Alert.alert('Error', 'Failed to start sauce — check console');
    }
  };

  const isEditing = (recipeId) => editingRecipeId === recipeId;
  const showRecipeContent = (recipeId) => !isEditing(recipeId);

  const renderRecipeItem = ({ item: recipe }) => (
    <View style={styles.recipeCard}>
      {showRecipeContent(recipe.id) && (
        <>
          <View style={styles.titleBar}>
            <Text style={styles.recipeTitle}>{recipe.name}</Text>
            <TouchableOpacity style={styles.editPencil} onPress={() => openEdit(recipe)}>
              <Text style={styles.editPencilText}>Edit</Text>
            </TouchableOpacity>
          </View>
          <ScrollView style={styles.ingredients}>
            {(recipe.ingredients || []).map((ing, i) => (
              <Text key={i} style={styles.ingredient}>• {ing}</Text>
            ))}
          </ScrollView>
          <TouchableOpacity style={styles.makeSauceButton} onPress={() => startSauce(recipe.id)}>
            <Text style={styles.makeSauceButtonText}>MAKE SAUCE</Text>
          </TouchableOpacity>
        </>
      )}
      {isEditing(recipe.id) && renderRecipeForm('Edit Recipe', 'Update Recipe')}
    </View>
  );

  const renderAddCard = () => (
    <TouchableOpacity style={styles.addCard} onPress={openAdd}>
      {!isAddingNew && (
        <View style={styles.addPlaceholder}>
          <Text style={styles.plusIcon}>+</Text>
          <Text style={styles.addRecipeText}>Add Recipe</Text>
        </View>
      )}
      {isAddingNew && renderRecipeForm('New Recipe', 'Save Recipe')}
    </TouchableOpacity>
  );

  const renderRecipeForm = (title, buttonText) => (
    <Modal
      visible={true}
      transparent={true}
      animationType="fade"
      onRequestClose={closeForm}
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.editOverlay}
      >
        <View style={styles.editPanel}>
          <Text style={styles.editPanelTitle}>{title}</Text>

          <TextInput
            style={styles.addTitleInput}
            value={formName}
            onChangeText={setFormName}
            placeholder="Recipe name..."
            placeholderTextColor="#999"
            autoFocus
          />

          <View style={styles.addIngredientsSection}>
            <View style={styles.ingredientInputRow}>
              <TextInput
                style={styles.ingredientInput}
                placeholder="Add ingredient..."
                placeholderTextColor="#999"
                value={currentIngredient}
                onChangeText={setCurrentIngredient}
                onSubmitEditing={addIngredient}
              />
              <TouchableOpacity style={styles.addIngredientBtn} onPress={addIngredient}>
                <Text style={styles.addIngredientBtnText}>+</Text>
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.addedIngredients}>
              {formIngredients.map((ing, i) => (
                <View key={i} style={styles.addedIngredientChip}>
                  <Text style={styles.addedIngredientText}>{ing}</Text>
                  <TouchableOpacity onPress={() => removeIngredient(i)}>
                    <Text style={styles.removeIngredientText}>×</Text>
                  </TouchableOpacity>
                </View>
              ))}
            </ScrollView>
          </View>

          <View style={styles.addFormButtons}>
            <TouchableOpacity style={styles.saveNewRecipe} onPress={saveRecipe}>
              <Text style={styles.saveNewRecipeText}>{buttonText}</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.cancelButton} onPress={closeForm}>
              <Text style={styles.cancelButtonText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#ff6b35" />
        <Text style={styles.loadingText}>SAUCE ROBOT STARTING UP...</Text>
        <Text style={styles.loadingSubtext}>{serverStatus}</Text>
      </View>
    );
  }

  if (!serverRunning || !serverUrl) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorTitle}>🔧 Server Not Running</Text>
        <Text style={styles.errorText}>
          The Sauce Robot server failed to start. This robot may need maintenance.
        </Text>
        <TouchableOpacity style={styles.restartButton} onPress={restartServer}>
          <Text style={styles.restartButtonText}>RESTART ROBOT</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.app}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>THE SAUCER</Text>
        <Text style={styles.debugText}>Recipes loaded: {recipes.length}</Text>

        <View style={styles.headerControls}>
          <TouchableOpacity
            style={styles.refreshButton}
            onPress={handleRefresh}
            disabled={isRefreshing}
          >
            <Text style={styles.refreshButtonText}>
              {isRefreshing ? '⟳' : '🔄'}
            </Text>
          </TouchableOpacity>

          <View style={styles.screenToggle}>
            <Text style={styles.screenToggleText}>Keep Screen On</Text>
            <Switch
              value={keepScreenOn}
              onValueChange={handleScreenToggle}
              trackColor={{ false: '#767577', true: '#ff0066' }}
              thumbColor={keepScreenOn ? '#ffffff' : '#f4f3f4'}
            />
          </View>
        </View>
      </View>

      <FlatList
        style={styles.recipesGrid}
        data={[...recipes, { id: 'add', isAddCard: true }]}
        renderItem={({ item }) =>
          item.isAddCard ? renderAddCard() : renderRecipeItem({ item })
        }
        keyExtractor={(item) => item.id?.toString() || 'add'}
        numColumns={1}
        contentContainerStyle={styles.recipesContainer}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>No recipes loaded yet...</Text>
            <TouchableOpacity style={styles.refreshButton} onPress={fetchRecipes}>
              <Text style={styles.refreshButtonText}>Refresh</Text>
            </TouchableOpacity>
          </View>
        }
      />
    </View>
  );
};

const styles = StyleSheet.create({
  // React Native compatible conversion of the original CSS
  app: {
    flex: 1,
    backgroundColor: '#0f0f0f',
    padding: 32, // 2rem = 32px
  },
  header: {
    alignItems: 'center',
    marginBottom: 48, // 3rem = 48px
  },
  headerTitle: {
    fontSize: 64, // 4rem = 64px
    color: '#ffbe0b',
    textAlign: 'center',
    fontWeight: 'bold',
  },
  debugText: {
    fontSize: 16,
    color: '#cccccc',
    textAlign: 'center',
    marginTop: 8,
  },
  headerControls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 16,
    paddingHorizontal: 16,
    gap: 20, // Add space between the buttons
  },
  refreshButton: {
    backgroundColor: '#ff6b35',
    width: 50,
    height: 50,
    borderRadius: 25,
    justifyContent: 'center',
    alignItems: 'center',
  },
  refreshButtonText: {
    fontSize: 20,
    color: 'white',
  },
  screenToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
    paddingVertical: 12,
    paddingHorizontal: 16, // More horizontal padding for the switch
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#333',
  },
  screenToggleText: {
    fontSize: 14,
    color: '#cccccc',
    marginRight: 8,
  },
  recipesGrid: {
    flex: 1,
  },
  recipesContainer: {
    paddingBottom: 48, // 3rem = 48px
  },
  recipeCard: {
    backgroundColor: '#1a1a1a',
    borderWidth: 2,
    borderColor: '#333',
    borderRadius: 16,
    padding: 32, // 2rem = 32px
    marginBottom: 32, // 2rem = 32px
    height: 500,
    justifyContent: 'space-between',
  },
  titleBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16, // 1rem = 16px
  },
  recipeTitle: {
    fontSize: 28, // 1.8rem = 28px
    color: '#ffbe0b',
    flex: 1,
    marginRight: 16,
  },
  editPencil: {
    paddingHorizontal: 16, // 0.8rem = 16px
    paddingVertical: 8, // 0.4rem = 8px
  },
  editPencilText: {
    fontSize: 16, // 1rem = 16px
    color: '#aaa',
    opacity: 0.7,
  },
  ingredients: {
    flex: 1,
    marginTop: 32, // 2rem = 32px
  },
  ingredient: {
    fontSize: 18, // 1.1rem = 18px
    color: '#fff',
    lineHeight: 28, // 1.8 * 16px = 28px
    marginBottom: 8,
  },
  makeSauceButton: {
    marginTop: 8, // 0.5rem = 8px
    paddingVertical: 24, // 1.5rem = 24px
    paddingHorizontal: 48, // 3rem = 48px
    backgroundColor: '#ff0066',
    borderRadius: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
  makeSauceButtonText: {
    color: 'white',
    fontSize: 28, // 1.8rem = 28px
    fontWeight: 'bold',
  },
  addCard: {
    backgroundColor: '#1a0033',
    borderWidth: 3,
    borderColor: '#ff0066',
    borderStyle: 'dashed',
    borderRadius: 16,
    marginBottom: 32, // 2rem = 32px
    height: 500,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addPlaceholder: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  plusIcon: {
    fontSize: 96, // 6rem = 96px
    color: '#ff0066',
    marginBottom: 16, // 1rem = 16px
  },
  addRecipeText: {
    fontSize: 24,
    color: '#ff0066',
  },
  // EDIT/ADD OVERLAY
  editOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(26, 26, 26, 0.98)',
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32, // 2rem = 32px
  },
  editPanel: {
    width: '100%',
    height: '90%',
    backgroundColor: '#1a1a1a',
    borderRadius: 16,
    padding: 32, // 2rem = 32px
    justifyContent: 'space-between',
  },
  editPanelTitle: {
    fontSize: 28, // 1.8rem = 28px
    color: '#ffbe0b',
    textAlign: 'center',
    marginBottom: 20, // 1.2rem = 20px approx
  },
  addTitleInput: {
    width: '95%',
    padding: 12, // 0.75rem = 12px
    fontSize: 24, // 1.6rem = 24px
    backgroundColor: '#333',
    borderWidth: 2,
    borderColor: '#ff0066',
    color: 'white',
    borderRadius: 8,
    textAlign: 'center',
    marginBottom: 32, // 2rem = 32px
  },
  addIngredientsSection: {
    flex: 1,
    gap: 16, // 1rem = 16px
  },
  ingredientInputRow: {
    flexDirection: 'row',
    gap: 8, // 0.5rem = 8px
  },
  ingredientInput: {
    flex: 1,
    padding: 12, // 0.75rem = 12px
    backgroundColor: 'rgba(0,0,0,0.5)',
    borderWidth: 2,
    borderColor: '#ff0066',
    color: 'white',
    borderRadius: 8,
  },
  addIngredientBtn: {
    paddingHorizontal: 16, // 1rem = 16px
    paddingVertical: 12, // 0.75rem = 12px
    backgroundColor: '#ff0066',
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addIngredientBtnText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  addedIngredients: {
    flex: 1,
    paddingRight: 8, // 0.5rem = 8px
    maxHeight: 250,
  },
  addedIngredientChip: {
    backgroundColor: '#ff0066',
    paddingVertical: 12, // 0.75rem = 12px
    paddingHorizontal: 16, // 1rem = 16px
    borderRadius: 20,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8, // 0.5rem = 8px
    gap: 8, // 0.5rem = 8px
  },
  addedIngredientText: {
    color: 'white',
    fontSize: 16,
    flex: 1,
  },
  removeIngredientText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  addFormButtons: {
    flexDirection: 'row',
    gap: 16, // 1rem = 16px
  },
  saveNewRecipe: {
    flex: 1,
    padding: 16, // 1rem = 16px
    backgroundColor: '#330066',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  saveNewRecipeText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  cancelButton: {
    flex: 1,
    padding: 16, // 1rem = 16px
    backgroundColor: '#ff0066',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cancelButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  // Loading and error states
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
  },
  loadingText: {
    fontSize: 48, // 3rem = 48px
    color: '#ff0066',
    marginTop: 120, // 20vh approximated
    textAlign: 'center',
  },
  loadingSubtext: {
    fontSize: 16,
    color: '#cccccc',
    marginTop: 16, // 1rem = 16px
    textAlign: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#1a1a1a',
  },
  errorTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#ff6b35',
    marginBottom: 20,
    textAlign: 'center',
  },
  errorText: {
    fontSize: 16,
    color: '#cccccc',
    textAlign: 'center',
    marginBottom: 30,
    lineHeight: 24,
  },
  restartButton: {
    backgroundColor: '#ff6b35',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 8,
  },
  restartButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyText: {
    fontSize: 18,
    color: '#cccccc',
    textAlign: 'center',
    marginBottom: 16,
  },
  refreshButton: {
    backgroundColor: '#1a1a1a', // Match screen toggle background
    paddingHorizontal: 20, // Increased from 16
    paddingVertical: 16, // Increased from 12
    borderRadius: 20, // Match screen toggle borderRadius
    borderWidth: 1,
    borderColor: '#333',
    minWidth: 60, // Add minimum width for consistency
  },
  refreshButtonText: {
    color: 'white',
    fontSize: 20,
    fontWeight: 'bold',
  },
});

export default App;
