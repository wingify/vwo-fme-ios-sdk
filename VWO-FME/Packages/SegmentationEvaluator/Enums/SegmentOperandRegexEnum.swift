/**
 * Copyright 2024 Wingify Software Pvt. Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/**
 * Regular expressions for segment operands.
 *
 * This enum defines regular expressions used for matching and evaluating different types of segment
 * operands.
 */
enum SegmentOperandRegexEnum: String {
    case lower = "^lower"
    case lowerMatch = "^lower\\((.*)\\)"
    case wildcard = "^wildcard"
    case wildcardMatch = "^wildcard\\((.*)\\)"
    case regex = "^regex"
    case regexMatch = "^regex\\((.*)\\)"
    case startingStar = "^\\*"
    case endingStar = "\\*$"
    case greaterThanMatch = "^gt\\((\\d+\\.?\\d*|\\.\\d+)\\)"
    case greaterThanEqualToMatch = "^gte\\((\\d+\\.?\\d*|\\.\\d+)\\)"
    case lessThanMatch = "^lt\\((\\d+\\.?\\d*|\\.\\d+)\\)"
    case lessThanEqualToMatch = "^lte\\((\\d+\\.?\\d*|\\.\\d+)\\)"
}