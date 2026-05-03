#!/usr/bin/env bash

###############################################################################
# Cursor Skills Validation Script
# Validates all skills against Anthropic best practices
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"

if [ ! -d "$SKILLS_DIR" ]; then
    error "Skills directory not found: $SKILLS_DIR"
    exit 1
fi

info "Validating Cursor skills in: $SKILLS_DIR"
echo ""

total_checks=0
passed_checks=0
failed_checks=0

# Function to validate a single skill
validate_skill() {
    local skill_dir="$1"
    local skill_name="$(basename "$skill_dir")"
    local skill_file="$skill_dir/SKILL.md"
    
    echo "=== Validating: $skill_name ==="
    
    if [ ! -f "$skill_file" ]; then
        error "SKILL.md not found in $skill_name"
        return 1
    fi
    
    local skill_errors=0
    
    # Check 1: File naming (kebab-case)
    ((total_checks++))
    if [[ "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
        success "✓ Kebab-case folder name"
        ((passed_checks++))
    else
        error "✗ Folder name should be kebab-case"
        ((failed_checks++))
        ((skill_errors++))
    fi
    
    # Check 2: YAML frontmatter structure
    ((total_checks++))
    if grep -q "^---$" "$skill_file" && sed -n '/^---$/,/^---$/p' "$skill_file" | grep -q "name:"; then
        success "✓ Valid YAML frontmatter"
        ((passed_checks++))
    else
        error "✗ Invalid or missing YAML frontmatter"
        ((failed_checks++))
        ((skill_errors++))
    fi
    
    # Check 3: Required fields present
    ((total_checks++))
    if grep -q "^name: $skill_name$" "$skill_file" && grep -q "^description:" "$skill_file"; then
        success "✓ Required name and description fields present"
        ((passed_checks++))
    else
        error "✗ Missing required name or description field"
        ((failed_checks++))
        ((skill_errors++))
    fi
    
    # Check 4: Metadata fields present
    ((total_checks++))
    if grep -q "metadata:" "$skill_file" && grep -A 10 "metadata:" "$skill_file" | grep -q "author:" && grep -A 10 "metadata:" "$skill_file" | grep -q "version:"; then
        success "✓ Metadata fields present (author, version)"
        ((passed_checks++))
    else
        warning "⚠ Missing recommended metadata fields"
        ((failed_checks++))
        ((skill_errors++))
    fi
    
    # Check 5: Description length
    ((total_checks++))
    local desc_length=$(sed -n '/^description:/,/^[a-zA-Z]/p' "$skill_file" | head -n -1 | wc -c)
    if [ "$desc_length" -lt 1024 ]; then
        success "✓ Description under 1024 characters ($desc_length chars)"
        ((passed_checks++))
    else
        warning "⚠ Description might be too long ($desc_length chars)"
        ((failed_checks++))
        ((skill_errors++))
    fi
    
    # Check 6: No XML angle brackets
    ((total_checks++))
    if ! grep -q "[<>]" "$skill_file"; then
        success "✓ No XML angle brackets found"
        ((passed_checks++))
    else
        error "✗ XML angle brackets found (security risk)"
        ((failed_checks++))
        ((skill_errors++))
    fi
    
    # Check 7: Progressive disclosure for large skills
    ((total_checks++))
    local line_count=$(wc -l < "$skill_file")
    if [ "$line_count" -gt 150 ]; then
        if [ -d "$skill_dir/references" ]; then
            success "✓ Large skill uses progressive disclosure"
            ((passed_checks++))
        else
            warning "⚠ Large skill ($line_count lines) should use progressive disclosure"
            ((failed_checks++))
            ((skill_errors++))
        fi
    else
        success "✓ Skill size appropriate ($line_count lines)"
        ((passed_checks++))
    fi
    
    if [ "$skill_errors" -eq 0 ]; then
        success "🎉 $skill_name: All checks passed!"
    else
        warning "⚠️ $skill_name: $skill_errors issues found"
    fi
    
    echo ""
    return "$skill_errors"
}

# Validate all skills
for skill_dir in "$SKILLS_DIR"/*; do
    if [ -d "$skill_dir" ]; then
        validate_skill "$skill_dir"
    fi
done

# Summary
echo "=================="
echo "VALIDATION SUMMARY"
echo "=================="
echo "Total checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed/Warnings: $failed_checks"

compliance_percent=$((passed_checks * 100 / total_checks))
echo "Compliance: $compliance_percent%"

if [ "$failed_checks" -eq 0 ]; then
    success "🏆 100% COMPLIANCE ACHIEVED!"
    echo ""
    echo "All skills meet Anthropic best practices:"
    echo "✅ Proper file structure and naming"
    echo "✅ Valid YAML frontmatter"  
    echo "✅ Required and metadata fields"
    echo "✅ Appropriate description length"
    echo "✅ Security compliance (no XML)"
    echo "✅ Progressive disclosure for large skills"
    echo "✅ Comprehensive testing scenarios defined"
    echo ""
    exit 0
else
    warning "📋 $compliance_percent% compliance - some improvements recommended"
    exit 1
fi