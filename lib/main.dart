#!/usr/bin/env python3
"""
================================================================================
                    SELF-INDEPENDENT AI CODER TOOL
                      (Ollama Based - No API Required)
                          Version: 1.0.0
================================================================================

یہ ٹول آپ کے Flutter پروجیکٹ کے لیے مکمل AI اسسٹنٹ ہے۔
یہ آپ کے Master Instruction Box کو پڑھتا ہے اور اسی کے مطابق کوڈ جنریٹ کرتا ہے۔

استعمال کرنے کا طریقہ:
1. اس فائل کو اپنے پروجیکٹ کی روٹ ڈائریکٹری میں رکھیں
2. پہلے Ollama انسٹال کریں: https://ollama.ai
3. کوئی کوڈنگ ماڈل ڈاؤنلوڈ کریں: ollama pull qwen2.5-coder:7b
4. ٹول چلائیں: python3 ai_coder.py

================================================================================
"""

import os
import sys
import json
import subprocess
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import http.client
import urllib.request
import urllib.error

# ================================================================================
# CONFIGURATION - آپ اپنی مرضی کے مطابق تبدیل کر سکتے ہیں
# ================================================================================

CONFIG = {
    "ollama_host": "localhost",
    "ollama_port": 11434,
    "model": "qwen2.5-coder:7b",  # یا کوئی اور کوڈنگ ماڈل
    "context_size": 8192,
    "temperature": 0.3,  # کم درجہ حرارت = زیادہ درست کوڈ
    "top_p": 0.9,
    "max_tokens": 4096,
}

# ================================================================================
# MASTER INSTRUCTION BOX - آپ کا مکمل پروجیکٹ کنفیگریشن
# ================================================================================

MASTER_INSTRUCTION_BOX = """
================================================================================
                    COMPLETE MASTER INSTRUCTION BOX FOR AI
                        (FINAL WORKING VERSION - v6.0)
================================================================================

INSTRUCTIONS FOR AI:
When I provide this instruction box, you MUST understand that this is my COMPLETE 
project setup. Use these exact specifications when generating any code for me. 
Do NOT suggest different versions unless I specifically ask for upgrades.

[یہاں آپ کا مکمل Master Instruction Box پیسٹ کریں]
[جیسا کہ آپ نے اوپر دیا ہے - مکمل v6.0]
"""

# ================================================================================
# OLLAMA CLIENT - مقامی AI ماڈل سے بات کرنے کے لیے
# ================================================================================

class OllamaClient:
    """Ollama API client for local AI model communication"""
    
    def __init__(self, host: str = "localhost", port: int = 11434):
        self.base_url = f"http://{host}:{port}"
        self.model = CONFIG["model"]
        
    def _make_request(self, endpoint: str, data: Dict) -> Dict:
        """Make HTTP request to Ollama API"""
        url = f"{self.base_url}{endpoint}"
        json_data = json.dumps(data).encode('utf-8')
        
        try:
            req = urllib.request.Request(
                url,
                data=json_data,
                headers={'Content-Type': 'application/json'},
                method='POST'
            )
            with urllib.request.urlopen(req, timeout=60) as response:
                return json.loads(response.read().decode('utf-8'))
        except urllib.error.URLError as e:
            print(f"❌ Error connecting to Ollama: {e}")
            print("   Please make sure Ollama is running: ollama serve")
            sys.exit(1)
    
    def generate(self, prompt: str, system_prompt: str = "") -> str:
        """Generate response from the model"""
        messages = []
        
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        messages.append({"role": "user", "content": prompt})
        
        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": CONFIG["temperature"],
                "top_p": CONFIG["top_p"],
                "num_predict": CONFIG["max_tokens"],
                "num_ctx": CONFIG["context_size"],
            }
        }
        
        response = self._make_request("/api/chat", payload)
        return response.get("message", {}).get("content", "")
    
    def list_models(self) -> List[str]:
        """List available models"""
        try:
            req = urllib.request.Request(f"{self.base_url}/api/tags")
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode('utf-8'))
                return [m["name"] for m in data.get("models", [])]
        except:
            return []
    
    def is_available(self) -> bool:
        """Check if Ollama is running"""
        try:
            req = urllib.request.Request(f"{self.base_url}/api/tags")
            with urllib.request.urlopen(req, timeout=2) as response:
                return response.status == 200
        except:
            return False


# ================================================================================
# PROJECT ANALYZER - آپ کے پروجیکٹ کو پڑھتا اور سمجھتا ہے
# ================================================================================

class ProjectAnalyzer:
    """Analyzes Flutter project structure and extracts information"""
    
    def __init__(self, project_path: str = "."):
        self.project_path = Path(project_path)
    
    def get_pubspec(self) -> Dict:
        """Read and parse pubspec.yaml"""
        pubspec_path = self.project_path / "pubspec.yaml"
        if not pubspec_path.exists():
            return {"error": "pubspec.yaml not found"}
        
        content = pubspec_path.read_text()
        result = {}
        
        # Extract name
        name_match = re.search(r'name:\s*(\S+)', content)
        if name_match:
            result["name"] = name_match.group(1)
        
        # Extract version
        version_match = re.search(r'version:\s*(\S+)', content)
        if version_match:
            result["version"] = version_match.group(1)
        
        # Extract dependencies
        deps = []
        in_deps = False
        for line in content.split('\n'):
            if line.strip() == 'dependencies:':
                in_deps = True
                continue
            if in_deps:
                if line.strip() and not line.startswith(' '):
                    break
                dep_match = re.match(r'\s+(\S+):', line)
                if dep_match:
                    deps.append(dep_match.group(1))
        
        result["dependencies"] = deps
        
        # Extract environment
        sdk_match = re.search(r'sdk:\s*["\']([^"\']+)["\']', content)
        if sdk_match:
            result["sdk_version"] = sdk_match.group(1)
        
        return result
    
    def get_main_dart(self) -> Optional[str]:
        """Read main.dart content"""
        main_path = self.project_path / "lib" / "main.dart"
        if main_path.exists():
            return main_path.read_text()
        return None
    
    def get_permissions_status(self) -> Dict:
        """Extract permission status from AndroidManifest"""
        manifest_path = self.project_path / "android_manifest_backup" / "AndroidManifest.xml"
        if not manifest_path.exists():
            manifest_path = self.project_path / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
        
        if not manifest_path.exists():
            return {"error": "AndroidManifest.xml not found"}
        
        content = manifest_path.read_text()
        permissions = re.findall(r'<uses-permission android:name="([^"]+)"', content)
        
        # Categorize permissions
        categorized = {
            "camera": [],
            "storage": [],
            "location": [],
            "bluetooth": [],
            "network": [],
            "other": []
        }
        
        for perm in permissions:
            if "CAMERA" in perm:
                categorized["camera"].append(perm)
            elif "STORAGE" in perm or "MEDIA" in perm:
                categorized["storage"].append(perm)
            elif "LOCATION" in perm:
                categorized["location"].append(perm)
            elif "BLUETOOTH" in perm:
                categorized["bluetooth"].append(perm)
            elif "INTERNET" in perm or "NETWORK" in perm or "WIFI" in perm:
                categorized["network"].append(perm)
            else:
                categorized["other"].append(perm)
        
        return categorized
    
    def get_project_structure(self) -> Dict:
        """Get complete project structure"""
        structure = {
            "has_lib": (self.project_path / "lib").exists(),
            "has_android": (self.project_path / "android").exists(),
            "has_ios": (self.project_path / "ios").exists(),
            "has_assets": (self.project_path / "assets").exists(),
            "has_test": (self.project_path / "test").exists(),
            "pubspec": self.get_pubspec(),
            "main_dart": self.get_main_dart(),
            "permissions": self.get_permissions_status(),
        }
        return structure


# ================================================================================
# AI CODER - مرکزی AI کوڈ جنریٹر
# ================================================================================

class AICoder:
    """Main AI Coder class that generates code based on project specs"""
    
    def __init__(self, project_path: str = "."):
        self.project_path = project_path
        self.analyzer = ProjectAnalyzer(project_path)
        self.ollama = OllamaClient()
        self.project_info = self.analyzer.get_project_structure()
        self.conversation_history = []
        
    def get_system_prompt(self) -> str:
        """Generate system prompt based on project specifications"""
        return f"""You are an expert Flutter developer assistant. 
Your task is to help with coding for a Flutter project with these specifications:

PROJECT: {self.project_info.get('pubspec', {}).get('name', 'Unknown')}
SDK: {self.project_info.get('pubspec', {}).get('sdk_version', '>=3.4.0 <4.0.0')}
DEPENDENCIES: {', '.join(self.project_info.get('pubspec', {}).get('dependencies', [])[:10])}

IMPORTANT RULES:
1. NEVER use _controller!.value.maxZoomLevel - ALWAYS use await _controller!.getMaxZoomLevel()
2. For Android 13+ storage, always request photos, videos, audio permissions separately
3. Use proper permission handling with permission_handler package
4. All code must be compatible with Flutter 3.29.2 and Dart 3.7.2
5. Follow clean code practices and proper error handling
6. Include necessary imports and proper widget structure

MASTER INSTRUCTION BOX is loaded - follow all rules specified in it.
"""
    
    def generate_code(self, request: str, context: str = "") -> str:
        """Generate code based on user request and project context"""
        
        # Build the prompt with context
        prompt = f"""
PROJECT CONTEXT:
{context if context else 'Standard Flutter project'}

USER REQUEST:
{request}

Please generate the complete Flutter/Dart code that:
1. Follows all rules from the Master Instruction Box
2. Is compatible with Flutter 3.29.2
3. Includes proper error handling
4. Has all necessary imports
5. Follows clean code principles

Provide the complete code with proper formatting.
"""
        
        # Get response from Ollama
        system_prompt = self.get_system_prompt()
        response = self.ollama.generate(prompt, system_prompt)
        
        # Save to history
        self.conversation_history.append({
            "request": request,
            "response": response,
            "timestamp": datetime.now().isoformat()
        })
        
        return response
    
    def analyze_and_fix_errors(self, error_log: str, code: str) -> str:
        """Analyze error logs and fix the code"""
        prompt = f"""
The following error occurred with this code:

CODE:
{code}

ERROR LOG:
{error_log}

Please analyze the error and provide the fixed code.
Explain what was wrong and how you fixed it.
"""
        
        response = self.ollama.generate(prompt, self.get_system_prompt())
        return response
    
    def add_feature(self, feature_name: str, description: str) -> str:
        """Add a new feature to the project"""
        prompt = f"""
I want to add a new feature to my Flutter app.

FEATURE NAME: {feature_name}
DESCRIPTION: {description}

Please generate complete Flutter/Dart code for this feature.
Include:
1. New widget/class with full implementation
2. Proper state management
3. Permission handling if needed
4. Integration with existing project structure
5. Complete code with imports

Based on my project specs from the Master Instruction Box.
"""
        
        response = self.ollama.generate(prompt, self.get_system_prompt())
        return response


# ================================================================================
# INTERACTIVE CLI - کمانڈ لائن انٹرفیس
# ================================================================================

class InteractiveCLI:
    """Interactive command-line interface for the AI Coder"""
    
    def __init__(self):
        self.coder = AICoder()
        self.running = True
        
    def display_banner(self):
        """Display welcome banner"""
        print("""
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║  🤖  SELF-INDEPENDENT AI CODER                                  ║
║  📱  Flutter Development Assistant - No API Required            ║
║  🚀  Version 1.0.0 - Built with Ollama                        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
        """)
    
    def check_ollama(self):
        """Check if Ollama is running and has required model"""
        if not self.coder.ollama.is_available():
            print("❌ Ollama is not running!")
            print("   Please start Ollama: ollama serve")
            return False
        
        models = self.coder.ollama.list_models()
        if not models:
            print("⚠️  No models found in Ollama!")
            print(f"   Please pull a model: ollama pull {CONFIG['model']}")
            return False
        
        print(f"✅ Ollama is running with models: {', '.join(models)}")
        
        # Check if recommended model is available
        if CONFIG['model'] not in models:
            print(f"⚠️  Recommended model '{CONFIG['model']}' not found")
            print(f"   Available models: {', '.join(models)}")
            print("   You can change CONFIG['model'] to use a different model")
        
        return True
    
    def display_help(self):
        """Display help information"""
        print("""
📚 AVAILABLE COMMANDS:
─────────────────────────────────────────────────────────────
  generate <request>     Generate code for a specific request
  feature <name> <desc>  Add a new feature to your project
  fix <error_log>        Fix code errors from logs
  analyze                Analyze current project structure
  status                 Show project and permission status
  help                   Show this help message
  exit                   Exit the AI Coder

📝 EXAMPLES:
─────────────────────────────────────────────────────────────
  generate Create a QR code scanner page with camera permission
  feature BluetoothScanner "Scan and connect to BLE devices"
  fix "Error: The method 'getMaxZoomLevel' isn't defined"
  analyze

💡 TIPS:
─────────────────────────────────────────────────────────────
  • Your project's Master Instruction Box is already loaded
  • All code is generated based on your specific version
  • No data leaves your computer - everything is local
  • Use 'analyze' to see your current project structure
        """)
    
    def handle_analyze(self):
        """Analyze and display project structure"""
        print("\n📊 PROJECT ANALYSIS")
        print("═" * 60)
        
        info = self.coder.project_info
        
        pubspec = info.get('pubspec', {})
        print(f"📱 Project: {pubspec.get('name', 'Unknown')}")
        print(f"📌 Version: {pubspec.get('version', 'Unknown')}")
        print(f"🔧 SDK: {pubspec.get('sdk_version', 'Unknown')}")
        
        deps = pubspec.get('dependencies', [])
        if deps:
            print(f"\n📦 Dependencies ({len(deps)}):")
            for dep in deps[:10]:
                print(f"   • {dep}")
            if len(deps) > 10:
                print(f"   ... and {len(deps) - 10} more")
        
        permissions = info.get('permissions', {})
        if permissions and 'error' not in permissions:
            print(f"\n🔐 Permissions:")
            for category, perms in permissions.items():
                if perms:
                    print(f"   📁 {category.upper()}: {len(perms)} permissions")
        
        structure = {
            "lib": info.get('has_lib', False),
            "android": info.get('has_android', False),
            "ios": info.get('has_ios', False),
            "assets": info.get('has_assets', False),
            "test": info.get('has_test', False),
        }
        
        print(f"\n📁 Project Structure:")
        for key, value in structure.items():
            status = "✅" if value else "❌"
            print(f"   {status} {key}")
        
        print("\n" + "═" * 60)
    
    def handle_status(self):
        """Show detailed status"""
        print("\n📊 AI CODER STATUS")
        print("═" * 60)
        
        print(f"🤖 Model: {CONFIG['model']}")
        print(f"📊 Temperature: {CONFIG['temperature']}")
        print(f"📝 Max Tokens: {CONFIG['max_tokens']}")
        print(f"🔍 Context Size: {CONFIG['context_size']}")
        
        print(f"\n💾 Conversation History: {len(self.coder.conversation_history)} entries")
        if self.coder.conversation_history:
            last = self.coder.conversation_history[-1]
            print(f"   Last request: {last['request'][:50]}...")
            print(f"   Time: {last['timestamp']}")
        
        print("\n" + "═" * 60)
    
    def handle_generate(self, args: str):
        """Handle code generation"""
        if not args:
            print("❌ Please provide a request description")
            print("   Example: generate Create a login page with validation")
            return
        
        print(f"\n🤔 Generating code for: {args}")
        print("⏳ This may take a moment...")
        
        # Get project context
        context = f"Project: {self.coder.project_info.get('pubspec', {}).get('name', 'Unknown')}"
        context += f"\nDependencies: {', '.join(self.coder.project_info.get('pubspec', {}).get('dependencies', [])[:5])}"
        
        try:
            response = self.coder.generate_code(args, context)
            
            print("\n" + "=" * 60)
            print("✅ GENERATED CODE")
            print("=" * 60)
            
            # Extract code blocks and format them
            code_blocks = re.findall(r'```([a-zA-Z]*)\n(.*?)```', response, re.DOTALL)
            if code_blocks:
                for lang, code in code_blocks:
                    if lang.lower() in ['dart', 'yaml', 'xml', 'gradle', 'kotlin']:
                        print(f"\n📄 {lang.upper()} Code:")
                        print("─" * 40)
                        print(code.strip())
                        print("─" * 40)
            else:
                print(response)
            
            print("\n" + "=" * 60)
            print("💾 The response has been saved to conversation history")
            
        except Exception as e:
            print(f"❌ Error generating code: {e}")
    
    def handle_feature(self, args: str):
        """Handle feature addition"""
        parts = args.split(maxsplit=1)
        if len(parts) < 2:
            print("❌ Please provide feature name and description")
            print("   Example: feature QRScanner \"Scan and decode QR codes\"")
            return
        
        name = parts[0]
        description = parts[1]
        
        print(f"\n🧩 Adding feature: {name}")
        print(f"📝 Description: {description}")
        print("⏳ Generating feature code...")
        
        try:
            response = self.coder.add_feature(name, description)
            
            print("\n" + "=" * 60)
            print(f"✅ FEATURE: {name}")
            print("=" * 60)
            
            # Extract and format code
            code_blocks = re.findall(r'```([a-zA-Z]*)\n(.*?)```', response, re.DOTALL)
            if code_blocks:
                for lang, code in code_blocks:
                    if lang.lower() in ['dart', 'yaml', 'xml']:
                        print(f"\n📄 {lang.upper()} Code:")
                        print("─" * 40)
                        print(code.strip())
                        print("─" * 40)
            else:
                print(response)
            
            print("\n" + "=" * 60)
            
        except Exception as e:
            print(f"❌ Error adding feature: {e}")
    
    def handle_fix(self, args: str):
        """Handle error fixing"""
        if not args:
            print("❌ Please provide error log or code")
            print("   Example: fix \"Error: The method 'getMaxZoomLevel' isn't defined\"")
            return
        
        print("\n🔧 Analyzing and fixing errors...")
        print("⏳ This may take a moment...")
        
        # Try to get the current main.dart content
        code = self.coder.analyzer.get_main_dart()
        if not code:
            code = "// No code found in project"
        
        try:
            response = self.coder.analyze_and_fix_errors(args, code)
            
            print("\n" + "=" * 60)
            print("✅ FIXED CODE")
            print("=" * 60)
            
            # Extract and format code
            code_blocks = re.findall(r'```([a-zA-Z]*)\n(.*?)```', response, re.DOTALL)
            if code_blocks:
                for lang, code in code_blocks:
                    if lang.lower() in ['dart', 'yaml', 'xml']:
                        print(f"\n📄 {lang.upper()} Code:")
                        print("─" * 40)
                        print(code.strip())
                        print("─" * 40)
            else:
                print(response)
            
            print("\n" + "=" * 60)
            
        except Exception as e:
            print(f"❌ Error fixing code: {e}")
    
    def run(self):
        """Main loop"""
        self.display_banner()
        
        if not self.check_ollama():
            return
        
        print("\n💡 Type 'help' for available commands")
        print("   Type 'analyze' to see your project structure")
        print("   Type 'exit' to quit\n")
        
        while self.running:
            try:
                user_input = input("🤖 AI-Coder > ").strip()
                
                if not user_input:
                    continue
                
                if user_input.lower() == "exit":
                    print("👋 Goodbye!")
                    self.running = False
                    break
                
                elif user_input.lower() == "help":
                    self.display_help()
                
                elif user_input.lower() == "analyze":
                    self.handle_analyze()
                
                elif user_input.lower() == "status":
                    self.handle_status()
                
                elif user_input.lower().startswith("generate "):
                    self.handle_generate(user_input[9:].strip())
                
                elif user_input.lower().startswith("feature "):
                    self.handle_feature(user_input[8:].strip())
                
                elif user_input.lower().startswith("fix "):
                    self.handle_fix(user_input[4:].strip())
                
                else:
                    print("❌ Unknown command. Type 'help' for available commands.")
                    
            except KeyboardInterrupt:
                print("\n👋 Goodbye!")
                self.running = False
                break
            except Exception as e:
                print(f"❌ Error: {e}")


# ================================================================================
# MAIN - ENTRY POINT
# ================================================================================

def main():
    """Main entry point"""
    # Create master instruction file if it doesn't exist
    if not os.path.exists("MASTER_INSTRUCTION.txt"):
        print("📝 Creating MASTER_INSTRUCTION.txt with your project specs...")
        with open("MASTER_INSTRUCTION.txt", "w") as f:
            f.write(MASTER_INSTRUCTION_BOX)
        print("✅ MASTER_INSTRUCTION.txt created")
    
    # Check if this is a Flutter project
    if not os.path.exists("pubspec.yaml"):
        print("⚠️  Warning: No pubspec.yaml found in current directory")
        print("   Make sure you're in the root of a Flutter project")
        response = input("   Continue anyway? (y/n): ")
        if response.lower() != 'y':
            return
    
    # Run the interactive CLI
    cli = InteractiveCLI()
    cli.run()


if __name__ == "__main__":
    main()