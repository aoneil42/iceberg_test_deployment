# Frontend - deck.gl Geospatial Viewer

Web-based visualization for the geospatial platform using deck.gl and MapLibre GL.

## Features

- 🗺️ Interactive map with pan/zoom
- 🔍 Spatial queries with bounding box
- ⚡ GeoArrow support for high performance
- 📊 GeoJSON fallback for compatibility
- 🎨 Customizable layer styling
- 💡 Feature tooltips

## Development

### Install Dependencies

```bash
npm install
```

### Run Development Server

```bash
npm run dev
```

Open http://localhost:5173

### Build for Production

```bash
npm run build
```

Output will be in `dist/` directory.

## Usage

1. **Enter API Endpoint**: Input your OGC API Features endpoint (e.g., `http://YOUR_EC2_IP:8080`)

2. **Select Collection**: Choose a collection from the dropdown

3. **Choose Format**: 
   - GeoJSON (default, universal compatibility)
   - GeoArrow (faster, smaller payloads)

4. **Load Data**: Click "Load Data" to fetch features for current viewport

5. **Interact**: Pan and zoom to query different areas automatically

## Configuration

### Custom Base Map

Edit `src/app.js` to change the base map:

```javascript
style: {
    sources: {
        'osm': {
            type: 'raster',
            tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
            tileSize: 256
        }
    },
    layers: [{ id: 'osm-layer', type: 'raster', source: 'osm' }]
}
```

### Layer Styling

Customize feature appearance:

```javascript
const layer = new GeoJsonLayer({
    id: 'features-layer',
    data: features,
    filled: true,
    getFillColor: [255, 0, 0, 100],  // Red fill
    getLineColor: [255, 255, 255],   // White outline
    lineWidthMinPixels: 2,
    pickable: true
});
```

### Query Parameters

Control query behavior:

```javascript
// Limit features
url += '&limit=5000'

// Select specific properties
url += '&properties=name,category,value'
```

## Architecture

```
Frontend
├── index.html          # Main HTML
└── app.js             # Application logic
    ├── Map Initialization (MapLibre)
    ├── deck.gl Layer Management
    ├── OGC API Client
    ├── GeoJSON Rendering
    └── GeoArrow Rendering
```

## Performance Tips

1. **Use GeoArrow**: Enable for 2-5x faster parsing and smaller payloads

2. **Limit Features**: Set reasonable limits (1000-10000) based on viewport

3. **Debounce Queries**: Wait for user to stop panning before refreshing

4. **Viewport Culling**: Only query features in visible bounds

5. **Layer Caching**: Cache rendered layers for zoom-only operations

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

Requires WebGL 2.0 support.

## Deployment

### Static Hosting (S3 + CloudFront)

```bash
npm run build

aws s3 sync dist/ s3://your-frontend-bucket/ --delete
aws cloudfront create-invalidation --distribution-id XXX --paths "/*"
```

### Nginx

```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /var/www/frontend/dist;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## Troubleshooting

### CORS Errors

Ensure OGC API has proper CORS headers:

```python
# In FastAPI
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)
```

### GeoArrow Not Loading

1. Check API supports Arrow format:
   ```bash
   curl -H "Accept: application/vnd.apache.arrow.stream" \
     http://YOUR_EC2_IP:8080/collections/test/items
   ```

2. Verify Arrow loader is installed:
   ```bash
   npm list @loaders.gl/arrow
   ```

### Poor Performance

1. Reduce query limit
2. Enable GeoArrow format
3. Check network throttling in DevTools
4. Verify spatial indexing on server

## Future Enhancements

- [ ] Layer controls for styling
- [ ] Multiple collection layers
- [ ] 3D visualization (deck.gl Trips layer)
- [ ] Time slider for temporal data
- [ ] Feature editing capabilities
- [ ] Export to GeoJSON/KML
- [ ] Measure tools
- [ ] Custom base map selection

## Resources

- [deck.gl Documentation](https://deck.gl/)
- [MapLibre GL JS](https://maplibre.org/)
- [loaders.gl](https://loaders.gl/)
- [GeoArrow Specification](https://geoarrow.org/)