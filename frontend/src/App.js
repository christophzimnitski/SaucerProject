import { useEffect, useState } from 'react';
import './App.css';

function App() {
    const [recipes, setRecipes] = useState([]);
    const [loading, setLoading] = useState(true);

    const [mode, setMode] = useState(null);

    const [formName, setFormName] = useState('');
    const [formIngredients, setFormIngredients] = useState([]);
    const [currentIngredient, setCurrentIngredient] = useState('');

    useEffect(() => {
        fetch('http://192.168.1.220:8080/api/recipes')
            .then(r => r.json())
            .then(data => setRecipes(Array.isArray(data) ? data : []))
            .finally(() => setLoading(false));
    }, []);

    const openEdit = (recipe) => {
        setMode(recipe);
        setFormName(recipe.name);
        setFormIngredients([...recipe.ingredients]);
        setCurrentIngredient('');
    };

    const openAdd = () => {
        setMode('NEW');
        setFormName('');
        setFormIngredients([]);
        setCurrentIngredient('');
    };

    const closeForm = () => {
        setMode(null);
        setFormName('');
        setFormIngredients([]);
        setCurrentIngredient('');
    };

    const addIngredient = () => {
        if (currentIngredient.trim()) {
            setFormIngredients(prev => [...prev, currentIngredient.trim()]);
            setCurrentIngredient('');
        }
    };

    const removeIngredient = (i) => {
        setFormIngredients(prev => prev.filter((_, idx) => idx !== i));
    };

    const saveRecipe = async () => {
        const name = formName.trim();
        if (!name || formIngredients.length === 0) {
            alert('Need a name and at least one ingredient!');
            return;
        }

        const payload = { name, ingredients: formIngredients };

        try {
            if (mode === 'NEW') {
                // ADD NEW
                const res = await fetch('http://192.168.1.220:8080/api/recipes', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) throw new Error();
                const saved = await res.json();
                setRecipes(prev => [...prev, saved]);
            } else {
                // EDIT EXISTING
                const res = await fetch(`http://192.168.1.220:8080/api/recipes/${mode.id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) throw new Error();
                const updated = await res.json();
                setRecipes(prev => prev.map(r => r.id === mode.id ? updated : r));
            }
            closeForm();
        } catch (err) {
            alert('Save failed — check console');
            console.error(err);
        }
    };

    if (loading) return <div className="loading">SAUCE ROBOT BOOTING UP...</div>;

    return (
        <div className="App">
            <header className="header">
                <h1>THE SAUCER</h1>
            </header>

            <div className="recipes-grid">
                {/* EXISTING RECIPES */}
                {recipes.map(recipe => (
                    <div key={recipe.id} className="recipe-card" style={{ position: 'relative' }}>

                        {/* HIDE ORIGINAL CONTENT WHEN EDITING THIS RECIPE */}
                        {!(mode && mode !== 'NEW' && mode.id === recipe.id) && (
                            <>
                                <div className="title-bar">
                                    <h2>{recipe.name}</h2>
                                    <button
                                        className="edit-pencil"
                                        onClick={() => openEdit(recipe)}
                                    >
                                        Edit
                                    </button>
                                </div>

                                <ul className="ingredients">
                                    {recipe.ingredients?.map((ing, i) => (
                                        <li key={i}>{ing}</li>
                                    ))}
                                </ul>

                                <button className="make-sauce-button">MAKE SAUCE</button>
                            </>
                        )}

                        {/* EDIT OVERLAY — FULLY COVERS THE CARD */}
                        {mode && mode !== 'NEW' && mode.id === recipe.id && (
                            <div className="edit-overlay" onClick={e => e.stopPropagation()}>
                                <div className="edit-panel">
                                    <h2>Edit Recipe</h2>

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
                                        <button onClick={saveRecipe} className="save-new-recipe">
                                            Update Recipe
                                        </button>
                                        <button onClick={closeForm} className="cancel-button">Cancel</button>
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                ))}

                {/* ADD RECIPE CARD */}
                <div id="add-card" className="recipe-card add-card" style={{ position: 'relative' }} onClick={openAdd}>

                    {/* HIDE + WHEN ADDING */}
                    {mode !== 'NEW' && (
                        <div className="add-placeholder">
                            <div className="plus-icon">+</div>
                            <h2>Add Recipe</h2>
                        </div>
                    )}

                    {/* ADD OVERLAY — FULLY COVERS THE CARD */}
                    {mode === 'NEW' && (
                        <div className="edit-overlay" onClick={e => e.stopPropagation()}>
                            <div className="edit-panel">
                                <h2>New Recipe</h2>

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
                                    <button onClick={saveRecipe} className="save-new-recipe">
                                        Save Recipe
                                    </button>
                                    <button onClick={closeForm}>Cancel</button>
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

export default App;