import os

for app in ['transport_app', 'voyageur_app']:
    lib_dir = os.path.join(app, 'lib')
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart') and file != 'bus_loading_indicator.dart':
                path = os.path.join(root, file)
                with open(path, 'r') as f:
                    content = f.read()
                
                if 'CircularProgressIndicator' in content:
                    rel_path = os.path.relpath(os.path.join(lib_dir, 'widgets', 'bus_loading_indicator.dart'), start=root)
                    
                    content = content.replace('CircularProgressIndicator', 'BusLoadingIndicator')
                    
                    if 'bus_loading_indicator.dart' not in content:
                        import_stmt = f"import '{rel_path}';\n"
                        lines = content.split('\n')
                        last_import = 0
                        for i, line in enumerate(lines):
                            if line.startswith('import '):
                                last_import = i
                        
                        lines.insert(last_import + 1, import_stmt.strip())
                        content = '\n'.join(lines)
                        
                    with open(path, 'w') as f:
                        f.write(content)
                    print(f"Replaced in {path}")
