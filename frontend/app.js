import { Deck } from '@deck.gl/core';
import { GeoJsonLayer, ScatterplotLayer } from '@deck.gl/layers';
import { load } from '@loaders.gl/core';
import { ArrowLoader } from '@loaders.gl/arrow';
import maplibregl from 'maplibre-gl';

// Application state
const state = {
    apiEndpoint: '',
    selectedCollection: null,
    collections: [],
    deck: null,
    map: null,
    useGeoArrow: false
};

// DOM elements
const apiEndpointInput = document.getElementById('api-endpoint');
const collectionSelect = document.getElementById('collection-select');
const useGeoArrowCheckbox = document.getElementById('use-geoarrow');
const loadButton = document.getElementById('load-button');
const errorMessage = document.getElementById('error-message');
const loadingDiv = document.getElementById('loading');

// Initialize map
function initializeMap() {
    state.map = new maplibregl.Map({
        container: 'map',
        style: {
            version: 8,
            sources: {
                'carto-dark': {
                    type: 'raster',
                    tiles: [
                        'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                    ],
                    tileSize: 256
                }
            },
            layers: [
                {
                    id: 'carto-dark-layer',
                    type: 'raster',
                    source: 'carto-dark',
                    minzoom: 0,
                    maxzoom: 22
                }
            ]
        },
        center: [-98.5795, 39.8283],
        zoom: 3,
        pitch: 0
    });

    state.deck = new Deck({
        canvas: 'deck-canvas',
        width: '100%',
        height: '100%',
        initialViewState: {
            longitude: -98.5795,
            latitude: 39.8283,
            zoom: 3,
            pitch: 0,
            bearing: 0
        },
        controller: true,
        onViewStateChange: ({ viewState }) => {
            state.map.jumpTo({
                center: [viewState.longitude, viewState.latitude],
                zoom: viewState.zoom,
                bearing: viewState.bearing,
                pitch: viewState.pitch
            });
            
            // Debounced data refresh
            if (state.selectedCollection && loadButton.textContent === 'Refresh Data') {
                clearTimeout(state.refreshTimeout);
                state.refreshTimeout = setTimeout(() => {
                    loadFeatures();
                }, 1000);
            }
        },
        getTooltip: ({ object }) => {
            if (!object) return null;
            
            const props = object.properties || {};
            const entries = Object.entries(props).slice(0, 5);
            
            return {
                html: `
                    <div style="background: white; padding: 10px; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.3);">
                        ${entries.map(([key, value]) => `
                            <div><strong>${key}:</strong> ${value}</div>
                        `).join('')}
                    </div>
                `,
                style: {
                    backgroundColor: 'transparent',
                    padding: '0'
                }
            };
        }
    });

    // Add deck.gl canvas to map
    state.map.getCanvas().style.position = 'absolute';
    state.deck.setProps({
        parent: document.getElementById('map'),
        style: { position: 'absolute', left: 0, top: 0 }
    });
}

// Fetch collections from OGC API
async function fetchCollections() {
    const endpoint = apiEndpointInput.value.trim();
    if (!endpoint) return;

    showLoading(true);
    clearError();

    try {
        const response = await fetch(`${endpoint}/collections`);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();
        state.collections = data.collections || [];
        state.apiEndpoint = endpoint;

        // Populate select
        collectionSelect.innerHTML = '<option value="">Select a collection...</option>';
        state.collections.forEach(collection => {
            const option = document.createElement('option');
            option.value = collection.id;
            option.textContent = collection.title || collection.id;
            collectionSelect.appendChild(option);
        });

        collectionSelect.disabled = false;
        showError('');

    } catch (error) {
        console.error('Error fetching collections:', error);
        showError(`Failed to fetch collections: ${error.message}`);
        collectionSelect.innerHTML = '<option value="">Error loading collections</option>';
        collectionSelect.disabled = true;
    } finally {
        showLoading(false);
    }
}

// Load features from selected collection
async function loadFeatures() {
    if (!state.selectedCollection) return;

    showLoading(true);
    clearError();

    try {
        const viewState = state.deck.viewState;
        const bounds = getViewportBounds(viewState);
        const bbox = `${bounds.west},${bounds.south},${bounds.east},${bounds.north}`;

        let url = `${state.apiEndpoint}/collections/${state.selectedCollection}/items?bbox=${bbox}&limit=10000`;
        
        let features;

        if (state.useGeoArrow) {
            // Fetch as GeoArrow
            url += '&f=arrow';
            const response = await fetch(url, {
                headers: {
                    'Accept': 'application/vnd.apache.arrow.stream'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const arrayBuffer = await response.arrayBuffer();
            const arrowTable = await load(arrayBuffer, ArrowLoader);
            
            // Convert Arrow to features (simplified)
            features = convertArrowToFeatures(arrowTable);

        } else {
            // Fetch as GeoJSON
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const geojson = await response.json();
            features = geojson.features || [];
        }

        // Create deck.gl layer
        const layer = new GeoJsonLayer({
            id: 'features-layer',
            data: { type: 'FeatureCollection', features },
            filled: true,
            stroked: true,
            lineWidthMinPixels: 1,
            getFillColor: [0, 150, 255, 100],
            getLineColor: [0, 100, 200, 255],
            pickable: true
        });

        state.deck.setProps({ layers: [layer] });

        loadButton.textContent = 'Refresh Data';
        showError('');

        // Update info
        document.getElementById('info').innerHTML = `
            <strong>${state.selectedCollection}</strong><br>
            Loaded ${features.length.toLocaleString()} features<br>
            ${state.useGeoArrow ? '(GeoArrow format)' : '(GeoJSON format)'}
        `;

    } catch (error) {
        console.error('Error loading features:', error);
        showError(`Failed to load features: ${error.message}`);
    } finally {
        showLoading(false);
    }
}

// Helper: Get viewport bounds
function getViewportBounds(viewState) {
    const { longitude, latitude, zoom } = viewState;
    
    // Approximate bounds calculation
    const latRad = latitude * Math.PI / 180;
    const metersPerPixel = 156543.03392 * Math.cos(latRad) / Math.pow(2, zoom);
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    const metersWidth = viewportWidth * metersPerPixel;
    const metersHeight = viewportHeight * metersPerPixel;
    
    const degreesPerMeterLon = 1 / 111320;
    const degreesPerMeterLat = 1 / 110540;
    
    const deltaLon = (metersWidth / 2) * degreesPerMeterLon;
    const deltaLat = (metersHeight / 2) * degreesPerMeterLat;
    
    return {
        west: longitude - deltaLon,
        south: latitude - deltaLat,
        east: longitude + deltaLon,
        north: latitude + deltaLat
    };
}

// Helper: Convert Arrow table to GeoJSON features (simplified)
function convertArrowToFeatures(arrowTable) {
    // This is a simplified conversion
    // In production, use proper Arrow to GeoJSON conversion
    const features = [];
    const numRows = arrowTable.numRows;
    
    for (let i = 0; i < numRows; i++) {
        const row = arrowTable.get(i);
        features.push({
            type: 'Feature',
            properties: row,
            geometry: null // Would need proper geometry parsing
        });
    }
    
    return features;
}

// UI helpers
function showLoading(show) {
    loadingDiv.classList.toggle('active', show);
}

function showError(message) {
    errorMessage.textContent = message;
}

function clearError() {
    errorMessage.textContent = '';
}

// Event listeners
apiEndpointInput.addEventListener('blur', fetchCollections);
apiEndpointInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        fetchCollections();
    }
});

collectionSelect.addEventListener('change', (e) => {
    state.selectedCollection = e.target.value;
    loadButton.disabled = !state.selectedCollection;
    loadButton.textContent = 'Load Data';
});

useGeoArrowCheckbox.addEventListener('change', (e) => {
    state.useGeoArrow = e.target.checked;
});

loadButton.addEventListener('click', loadFeatures);

// Initialize
initializeMap();

// Try to load from localStorage or URL param
const savedEndpoint = localStorage.getItem('ogc-api-endpoint');
if (savedEndpoint) {
    apiEndpointInput.value = savedEndpoint;
    fetchCollections();
} else {
    // Try to detect from URL
    const urlParams = new URLSearchParams(window.location.search);
    const endpoint = urlParams.get('api');
    if (endpoint) {
        apiEndpointInput.value = endpoint;
        fetchCollections();
    }
}

// Save endpoint on change
apiEndpointInput.addEventListener('change', () => {
    localStorage.setItem('ogc-api-endpoint', apiEndpointInput.value);
});