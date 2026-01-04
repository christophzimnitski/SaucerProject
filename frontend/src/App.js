import { useEffect, useState } from 'react';
import './App.css';

const API_BASE_URL = '/api/recipes';

function App() {
    const [recipes, setRecipes] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editingRecipeId, setEditingRecipeId] = useState(null);
    const [isAddingNew, setIsAddingNew] = useState(false);
    
    const [formName, setFormName] = useState('');
    const [formIngredients, setFormIngredients] = useState([]);
    const [currentIngredient, setCurrentIngredient] = useState('');

    useEffect(() => {
        fetch(API_BASE_URL)
            .then(r => r.json())
            .then(data => setRecipes(Array.isArray(data) ? data : []))
            .finally(() => setLoading(false));
    }, []);

    const resetForm = () => {
        setFormName('');
        setFormIngredients([]);
        setCurrentIngredient('');
    };

    const openEdit = (recipe) => {
        setEditingRecipeId(recipe.id);
        setIsAddingNew(false);
        setFormName(recipe.name);
        setFormIngredients([...recipe.ingredients]);
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
            alert('Need a name and at least one ingredient!');
            return;
        }

        const payload = { name, ingredients: formIngredients };
        const url = isAddingNew 
            ? API_BASE_URL 
            : `${API_BASE_URL}/${editingRecipeId}`;
        const method = isAddingNew ? 'POST' : 'PUT';

        try {
            const res = await fetch(url, {
                method,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            if (!res.ok) throw new Error();
            
            const saved = await res.json();
            if (isAddingNew) {
                setRecipes(prev => [...prev, saved]);
            } else {
                setRecipes(prev => prev.map(r => r.id === editingRecipeId ? saved : r));
            }
            closeForm();
        } catch (err) {
            alert('Save failed — check console');
            console.error(err);
        }
    };

    const startSauce = async (recipeId) => {
        try {
            const res = await fetch(`${API_BASE_URL}/start-sauce/${recipeId}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });
            if (!res.ok) throw new Error();
            const message = await res.text();
            alert(message);
        } catch (err) {
            alert('Failed to start sauce — check console');
            console.error(err);
        }
    };

    const isEditing = (recipeId) => editingRecipeId === recipeId;
    const showRecipeContent = (recipeId) => !isEditing(recipeId);

    const renderRecipeForm = (title, buttonText) => (
        <div className="edit-overlay" onClick={e => e.stopPropagation()}>
            <div className="edit-panel">
                <h2>{title}</h2>
                <input
                    value={formName}
                    onChange={e => setFormName(e.target.value)}
                    className="add-title-input"
                    placeholder="Recipe name..."
                    autoFocus
                />
                <div className="add-ingredients-section">
                    <div className="ingredient-input-row">
                        <input
                            type="text"
                            placeholder="Add ingredient..."
                            value={currentIngredient}
                            onChange={e => setCurrentIngredient(e.target.value)}
                            onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), addIngredient())}
                        />
                        <button onClick={addIngredient} className="add-ingredient-btn">+</button>
                    </div>
                    <div className="added-ingredients">
                        {formIngredients.map((ing, i) => (
                            <span key={i} className="added-ingredient-chip">
                                {ing}
                                <button onClick={() => removeIngredient(i)} className="remove-ingredient">×</button>
                            </span>
                        ))}
                    </div>
                </div>
                <div className="add-form-buttons">
                    <button onClick={saveRecipe} className="save-new-recipe">{buttonText}</button>
                    <button onClick={closeForm} className="cancel-button">Cancel</button>
                </div>
            </div>
        </div>
    );

    if (loading) return <div className="loading">SAUCE ROBOT BOOTING UP...</div>;

    return (
        <div className="App">
            <header className="header">
                <h1>THE SAUCER</h1>
            </header>
            <div className="recipes-grid">
                {recipes.map(recipe => (
                    <div key={recipe.id} className="recipe-card" style={{ position: 'relative' }}>
                        {showRecipeContent(recipe.id) && (
                            <>
                                <div className="title-bar">
                                    <h2>{recipe.name}</h2>
                                    <button className="edit-pencil" onClick={() => openEdit(recipe)}>
                                        Edit
                                    </button>
                                </div>
                                <ul className="ingredients">
                                    {recipe.ingredients?.map((ing, i) => (
                                        <li key={i}>{ing}</li>
                                    ))}
                                </ul>
                                <button className="make-sauce-button" onClick={() => startSauce(recipe.id)}>
                                    MAKE SAUCE
                                </button>
                            </>
                        )}
                        {isEditing(recipe.id) && renderRecipeForm('Edit Recipe', 'Update Recipe')}
                    </div>
                ))}
                <div className="recipe-card add-card" style={{ position: 'relative' }} onClick={openAdd}>
                    {!isAddingNew && (
                        <div className="add-placeholder">
                            <div className="plus-icon">+</div>
                            <h2>Add Recipe</h2>
                        </div>
                    )}
                    {isAddingNew && renderRecipeForm('New Recipe', 'Save Recipe')}
                </div>
            </div>
        </div>
    );
}

export default App;